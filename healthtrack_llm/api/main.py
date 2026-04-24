"""
HealthTrack Nutrition API
─────────────────────────
Combines two AI systems:
1. Mini LLM (PyTorch transformer) → predicts nutrition values
2. Groq LLaMA 3 (free API)       → generates real health advice

Architecture:
Flutter app → FastAPI → Mini LLM (nutrition)
                     → Groq LLaMA 3 (advice)
                     → Combined response → Flutter app
"""

import torch
import json
import sys
import os
from dotenv import load_dotenv

sys.path.append(os.path.join(os.path.dirname(__file__), ".."))
load_dotenv()

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from groq import Groq
from model.model import FoodNutritionLLM, FoodTokenizer

# ── App setup ─────────────────────────────────────────────────────────────────
app = FastAPI(
    title=       "HealthTrack Nutrition API",
    description= "Mini LLM + Groq LLaMA 3 for health advice",
    version=     "2.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Global state ──────────────────────────────────────────────────────────────
nutrition_model = None
norm_stats      = None
groq_client     = None


@app.on_event("startup")
async def load_resources():
    global nutrition_model, norm_stats, groq_client


     # Auto-train if model does not exist
    if not os.path.exists("model/food_model.pth"):
        print("Model not found — running training...")
        import subprocess
        subprocess.run(["python", "data/prepare_dataset.py"])
        subprocess.run(["python", "model/train.py"])
        print("Training complete")

    # Load model
    print("Loading Mini LLM...")

    # Load PyTorch mini LLM
    print("Loading Mini LLM (PyTorch)...")
    nutrition_model = FoodNutritionLLM()
    nutrition_model.load_state_dict(
        torch.load("model/food_model.pth", map_location="cpu"))
    nutrition_model.eval()
    print("✅ Mini LLM loaded")

    # Load normalization stats
    with open("model/normalization_stats.json") as f:
        norm_stats = json.load(f)
    print("✅ Normalization stats loaded")

    # Initialize Groq client
    api_key = os.getenv("GROQ_API_KEY")
    if api_key:
        groq_client = Groq(api_key=api_key)
        print("✅ Groq client initialized")
    else:
        print("⚠️  No Groq API key found — advice will be rule-based")


# ── Schemas ───────────────────────────────────────────────────────────────────
class FoodRequest(BaseModel):
    food_name:           str
    serving_g:           float = 100.0
    user_name:           str   = "User"
    user_goal:           str   = "Stay Fit"
    user_streak:         int   = 0
    user_weight:         float = 70.0
    user_target_weight:  float = 65.0
    calories_today:      float = 0.0
    daily_calorie_goal:  float = 2000.0
    meals_today:         int   = 0


class MealSuggestionRequest(BaseModel):
    user_name:          str   = "User"
    user_goal:          str   = "Stay Fit"
    calories_remaining: float = 500.0
    protein_today:      float = 0.0
    carbs_today:        float = 0.0
    fat_today:          float = 0.0
    meal_type:          str   = "dinner"   # breakfast/lunch/dinner/snack


class DailyCoachRequest(BaseModel):
    user_name:          str   = "User"
    user_goal:          str   = "Stay Fit"
    streak:             int   = 0
    health_score:       float = 0.0
    calories_today:     float = 0.0
    daily_calorie_goal: float = 2000.0
    current_weight:     float = 70.0
    target_weight:      float = 65.0
    meals_logged:       int   = 0


class NutritionResponse(BaseModel):
    food_name:        str
    serving_g:        float
    calories:         float
    protein_g:        float
    fat_g:            float
    carbs_g:          float
    fiber_g:          float
    sugar_g:          float
    food_advice:      str
    meal_rating:      str
    confidence:       str
    calories_remaining: float
    ai_powered:       bool


class MealSuggestionResponse(BaseModel):
    suggestions:      list[str]
    reasoning:        str
    estimated_calories: str


class DailyCoachResponse(BaseModel):
    greeting:         str
    main_advice:      str
    action_items:     list[str]
    motivation:       str


# ── Helper: predict nutrition using Mini LLM ──────────────────────────────────
def predict_nutrition_mini_llm(food_name: str, serving_g: float) -> dict:
    """
    Uses the trained PyTorch transformer to predict
    nutrition values for a given food name.
    Values are per serving (scaled from per-100g).
    """
    tokenizer = FoodTokenizer()
    tokens    = tokenizer.encode(food_name).unsqueeze(0)

    with torch.no_grad():
        output = nutrition_model(tokens).squeeze(0).cpu().numpy()

    nutrition_keys = [
        "calories", "protein_g", "fat_g",
        "carbs_g",  "fiber_g",   "sugar_g",
    ]

    # Denormalize from 0-1 back to real values
    raw = {
        key: float(output[i]) * norm_stats[key]
        for i, key in enumerate(nutrition_keys)
    }

    # Scale by serving size (model predicts per 100g)
    scale = serving_g / 100.0
    return {k: round(v * scale, 1) for k, v in raw.items()}


# ── Helper: generate food advice using Groq ───────────────────────────────────
def generate_food_advice(
    food_name:     str,
    nutrition:     dict,
    user_name:     str,
    user_goal:     str,
    user_streak:   int,
    calories_today: float,
    daily_goal:    float,
    meals_today:   int,
) -> tuple[str, str]:
    """
    Calls Groq LLaMA 3 to generate personalized food advice.
    Returns (advice_text, meal_rating).
    """
    if groq_client is None:
        return _rule_based_advice(food_name, nutrition, user_goal), "Good"

    calories_remaining = daily_goal - calories_today - nutrition["calories"]

    prompt = f"""
You are a friendly health coach inside the HealthTrack mobile app.
A user just logged a meal. Give short, specific, encouraging advice.

USER PROFILE:
- Name: {user_name}
- Goal: {user_goal}
- Current streak: {user_streak} days
- Meals logged today: {meals_today}

MEAL LOGGED:
- Food: {food_name}
- Calories: {nutrition['calories']} kcal
- Protein: {nutrition['protein_g']}g
- Fat: {nutrition['fat_g']}g
- Carbs: {nutrition['carbs_g']}g
- Fiber: {nutrition['fiber_g']}g
- Sugar: {nutrition['sugar_g']}g

DAILY PROGRESS:
- Calories eaten today (before this meal): {calories_today} kcal
- Daily calorie goal: {daily_goal} kcal
- Calories remaining after this meal: {calories_remaining:.0f} kcal

RESPOND IN THIS EXACT FORMAT (nothing else):
ADVICE: [2 sentences of specific, personalized advice about this meal]
RATING: [one of: Excellent / Good / Fair / High Calorie / Low Protein]

Rules:
- Be specific to the food and user's goal
- Mention the nutrition if relevant
- Be encouraging, never harsh
- Keep it under 50 words total
"""

    try:
        response = groq_client.chat.completions.create(
            model="llama3-8b-8192",
            messages=[
                {
                    "role":    "system",
                    "content": (
                        "You are a concise, friendly health coach. "
                        "Always respond in the exact format requested. "
                        "Never add extra text."
                    ),
                },
                {"role": "user", "content": prompt},
            ],
            max_tokens=120,
            temperature=0.7,
        )

        text   = response.choices[0].message.content.strip()
        advice = "Keep tracking your meals!"
        rating = "Good"

        for line in text.split("\n"):
            if line.startswith("ADVICE:"):
                advice = line.replace("ADVICE:", "").strip()
            elif line.startswith("RATING:"):
                rating = line.replace("RATING:", "").strip()

        return advice, rating

    except Exception as e:
        print(f"Groq error: {e}")
        return _rule_based_advice(food_name, nutrition, user_goal), "Good"


# ── Helper: generate meal suggestions using Groq ──────────────────────────────
def generate_meal_suggestions(
    user_name:          str,
    user_goal:          str,
    calories_remaining: float,
    protein_today:      float,
    carbs_today:        float,
    fat_today:          float,
    meal_type:          str,
) -> tuple[list[str], str, str]:
    """
    Calls Groq to suggest meals based on remaining calories
    and today's nutrition so far.
    Returns (suggestions list, reasoning, calorie estimate).
    """
    if groq_client is None:
        return (
            ["Grilled chicken with vegetables",
             "Fish with brown rice",
             "Vegetable soup with bread"],
            "High protein options to meet your daily goals.",
            "300-500 kcal each",
        )

    prompt = f"""
You are a nutrition expert in the HealthTrack app.
Suggest 3 specific meal options for {user_name}'s {meal_type}.

USER GOAL: {user_goal}
CALORIES REMAINING TODAY: {calories_remaining:.0f} kcal
NUTRITION TODAY SO FAR:
- Protein: {protein_today:.0f}g
- Carbs: {carbs_today:.0f}g  
- Fat: {fat_today:.0f}g

RESPOND IN THIS EXACT FORMAT:
MEAL1: [specific meal name]
MEAL2: [specific meal name]
MEAL3: [specific meal name]
REASON: [one sentence why these are good choices]
CALORIES: [estimated calorie range like "400-500 kcal each"]

Rules:
- Be specific (e.g. "Grilled tilapia with jollof rice" not just "fish")
- Match the remaining calories — do not suggest huge meals if calories are low
- Consider what nutrients they are missing today
- Include at least one African/local food option
"""

    try:
        response = groq_client.chat.completions.create(
            model="llama3-8b-8192",
            messages=[
                {
                    "role":    "system",
                    "content": (
                        "You are a nutrition expert. "
                        "Always respond in the exact format. "
                        "Be specific and practical."
                    ),
                },
                {"role": "user", "content": prompt},
            ],
            max_tokens=200,
            temperature=0.8,
        )

        text        = response.choices[0].message.content.strip()
        suggestions = []
        reasoning   = "Balanced meals to meet your goals."
        cal_range   = "300-500 kcal each"

        for line in text.split("\n"):
            line = line.strip()
            if line.startswith("MEAL1:"):
                suggestions.append(line.replace("MEAL1:", "").strip())
            elif line.startswith("MEAL2:"):
                suggestions.append(line.replace("MEAL2:", "").strip())
            elif line.startswith("MEAL3:"):
                suggestions.append(line.replace("MEAL3:", "").strip())
            elif line.startswith("REASON:"):
                reasoning = line.replace("REASON:", "").strip()
            elif line.startswith("CALORIES:"):
                cal_range = line.replace("CALORIES:", "").strip()

        if not suggestions:
            suggestions = [
                "Grilled chicken with vegetables",
                "Fish with brown rice",
                "Vegetable soup with bread",
            ]

        return suggestions, reasoning, cal_range

    except Exception as e:
        print(f"Groq error: {e}")
        return (
            ["Grilled chicken with vegetables",
             "Fish with brown rice",
             "Vegetable soup with bread"],
            "Balanced options for your goal.",
            "300-500 kcal each",
        )


# ── Helper: daily health coaching using Groq ──────────────────────────────────
def generate_daily_coaching(
    user_name:          str,
    user_goal:          str,
    streak:             int,
    health_score:       float,
    calories_today:     float,
    daily_calorie_goal: float,
    current_weight:     float,
    target_weight:      float,
    meals_logged:       int,
) -> tuple[str, str, list[str], str]:
    """
    Calls Groq to generate a full daily health coaching message.
    Returns (greeting, main_advice, action_items, motivation).
    """
    if groq_client is None:
        return (
            f"Good day, {user_name}!",
            "Stay consistent with your health goals today.",
            ["Log all your meals", "Drink 8 glasses of water",
             "Stay active"],
            "Every healthy choice counts!",
        )

    weight_diff = current_weight - target_weight
    calorie_pct = (calories_today / daily_calorie_goal * 100
                   if daily_calorie_goal > 0 else 0)

    prompt = f"""
You are a personal health coach giving a daily check-in for {user_name}.

USER STATS:
- Goal: {user_goal}
- Health score: {health_score:.0f}%
- Current streak: {streak} days
- Current weight: {current_weight}kg
- Target weight: {target_weight}kg
- Weight difference: {weight_diff:+.1f}kg to goal
- Calories today: {calories_today:.0f} / {daily_calorie_goal:.0f} kcal
  ({calorie_pct:.0f}% of daily goal)
- Meals logged today: {meals_logged}

RESPOND IN THIS EXACT FORMAT:
GREETING: [personalized greeting based on their progress]
ADVICE: [2-3 sentences of specific advice based on their stats today]
ACTION1: [specific action they should take today]
ACTION2: [specific action they should take today]
ACTION3: [specific action they should take today]
MOTIVATION: [one powerful motivational sentence]

Rules:
- Reference their actual numbers
- Be specific not generic
- If streak is high, celebrate it
- If calories are too low or too high, address it
- Keep total response under 100 words
"""

    try:
        response = groq_client.chat.completions.create(
            model="llama3-8b-8192",
            messages=[
                {
                    "role":    "system",
                    "content": (
                        "You are an encouraging personal health coach. "
                        "Always use the exact format requested. "
                        "Be specific, warm, and motivating."
                    ),
                },
                {"role": "user", "content": prompt},
            ],
            max_tokens=250,
            temperature=0.8,
        )

        text         = response.choices[0].message.content.strip()
        greeting     = f"Good day, {user_name}!"
        advice       = "Stay consistent with your health goals."
        action_items = []
        motivation   = "Every healthy choice counts!"

        for line in text.split("\n"):
            line = line.strip()
            if line.startswith("GREETING:"):
                greeting = line.replace("GREETING:", "").strip()
            elif line.startswith("ADVICE:"):
                advice = line.replace("ADVICE:", "").strip()
            elif line.startswith("ACTION1:"):
                action_items.append(line.replace("ACTION1:", "").strip())
            elif line.startswith("ACTION2:"):
                action_items.append(line.replace("ACTION2:", "").strip())
            elif line.startswith("ACTION3:"):
                action_items.append(line.replace("ACTION3:", "").strip())
            elif line.startswith("MOTIVATION:"):
                motivation = line.replace("MOTIVATION:", "").strip()

        if not action_items:
            action_items = [
                "Log all your meals today",
                "Drink at least 8 glasses of water",
                "Get 30 minutes of physical activity",
            ]

        return greeting, advice, action_items, motivation

    except Exception as e:
        print(f"Groq error: {e}")
        return (
            f"Good day, {user_name}!",
            "Stay consistent with your health goals today.",
            ["Log all your meals", "Drink 8 glasses of water",
             "Stay active"],
            "Every healthy choice counts!",
        )


# ── Fallback: rule-based advice ───────────────────────────────────────────────
def _rule_based_advice(food_name, nutrition, goal) -> str:
    cals    = nutrition["calories"]
    protein = nutrition["protein_g"]
    sugar   = nutrition["sugar_g"]

    if goal == "Lose Weight" and cals > 400:
        return (f"{food_name.title()} is calorie-dense at {cals:.0f} kcal. "
                f"Consider a smaller portion next time.")
    elif goal == "Build Muscle" and protein > 20:
        return (f"Great protein source — {protein:.0f}g will support "
                f"your muscle building goals.")
    elif sugar > 20:
        return (f"High sugar content ({sugar:.0f}g). "
                f"Balance this with low-sugar foods for the rest of the day.")
    return f"{food_name.title()} logged — {cals:.0f} kcal. Keep going!"


def _assess_confidence(food_name: str) -> str:
    common = [
        "rice", "chicken", "beef", "egg", "bread", "fish", "banana",
        "apple", "milk", "pasta", "potato", "beans", "jollof", "fufu",
        "banku", "kelewele", "waakye", "plantain", "yam", "tilapia",
    ]
    return "high" if any(f in food_name.lower() for f in common) else "medium"


# ── ENDPOINTS ─────────────────────────────────────────────────────────────────

@app.post("/predict", response_model=NutritionResponse)
async def predict_nutrition(request: FoodRequest):
    """
    Main endpoint — predicts nutrition using Mini LLM
    and generates advice using Groq LLaMA 3.
    """
    if nutrition_model is None:
        raise HTTPException(status_code=503, detail="Model not loaded")

    food_name = request.food_name.lower().strip()
    if not food_name:
        raise HTTPException(status_code=400, detail="Food name required")

    # 1. Mini LLM predicts nutrition
    nutrition = predict_nutrition_mini_llm(food_name, request.serving_g)

    # 2. Groq generates real advice
    advice, rating = generate_food_advice(
        food_name=      food_name,
        nutrition=      nutrition,
        user_name=      request.user_name,
        user_goal=      request.user_goal,
        user_streak=    request.user_streak,
        calories_today= request.calories_today,
        daily_goal=     request.daily_calorie_goal,
        meals_today=    request.meals_today,
    )

    calories_remaining = max(
        0, request.daily_calorie_goal
           - request.calories_today
           - nutrition["calories"]
    )

    return NutritionResponse(
        food_name=         request.food_name,
        serving_g=         request.serving_g,
        calories=          nutrition["calories"],
        protein_g=         nutrition["protein_g"],
        fat_g=             nutrition["fat_g"],
        carbs_g=           nutrition["carbs_g"],
        fiber_g=           nutrition["fiber_g"],
        sugar_g=           nutrition["sugar_g"],
        food_advice=       advice,
        meal_rating=       rating,
        confidence=        _assess_confidence(food_name),
        calories_remaining= calories_remaining,
        ai_powered=        groq_client is not None,
    )


@app.post("/meal-suggestions", response_model=MealSuggestionResponse)
async def suggest_meals(request: MealSuggestionRequest):
    """
    Suggests 3 specific meals based on remaining calories
    and what the user has already eaten today.
    """
    suggestions, reasoning, cal_estimate = generate_meal_suggestions(
        user_name=          request.user_name,
        user_goal=          request.user_goal,
        calories_remaining= request.calories_remaining,
        protein_today=      request.protein_today,
        carbs_today=        request.carbs_today,
        fat_today=          request.fat_today,
        meal_type=          request.meal_type,
    )

    return MealSuggestionResponse(
        suggestions=        suggestions,
        reasoning=          reasoning,
        estimated_calories= cal_estimate,
    )


@app.post("/daily-coach", response_model=DailyCoachResponse)
async def daily_coaching(request: DailyCoachRequest):
    """
    Generates a full personalized daily health coaching
    message based on the user's stats and progress.
    Called from the dashboard every morning.
    """
    greeting, advice, actions, motivation = generate_daily_coaching(
        user_name=          request.user_name,
        user_goal=          request.user_goal,
        streak=             request.streak,
        health_score=       request.health_score,
        calories_today=     request.calories_today,
        daily_calorie_goal= request.daily_calorie_goal,
        current_weight=     request.current_weight,
        target_weight=      request.target_weight,
        meals_logged=       request.meals_logged,
    )

    return DailyCoachResponse(
        greeting=     greeting,
        main_advice=  advice,
        action_items= actions,
        motivation=   motivation,
    )


@app.get("/health")
async def health_check():
    return {
        "status":       "healthy",
        "mini_llm":     nutrition_model is not None,
        "groq_active":  groq_client is not None,
        "version":      "2.0.0",
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000, reload=True)