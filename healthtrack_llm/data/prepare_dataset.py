"""
Downloads USDA FoodData Central and Open Food Facts datasets,
cleans them, combines them into one unified CSV for training.
"""

import pandas as pd
import requests
import json
import os

# ── USDA API ──────────────────────────────────────────────────────────────────
# Get a free API key at: https://fdc.nal.usda.gov/api-guide.html
USDA_API_KEY = "DEMO_KEY"  # Replace with your free key
USDA_BASE    = "https://api.nal.usda.gov/fdc/v1"

def fetch_usda_foods(query_terms):
    """
    Fetches nutrition data for a list of food names from USDA API.
    Returns a list of dicts with food name and nutrition per 100g.
    """
    foods = []

    for term in query_terms:
        print(f"Fetching USDA data for: {term}")
        url    = f"{USDA_BASE}/foods/search"
        params = {
            "query":    term,
            "pageSize": 3,
            "api_key":  USDA_API_KEY,
        }

        try:
            resp = requests.get(url, params=params, timeout=10)
            data = resp.json()

            for food in data.get("foods", [])[:1]:  # Take top result only
                nutrients = {n["nutrientName"]: n["value"]
                             for n in food.get("foodNutrients", [])}

                foods.append({
                    "food_name":    food["description"].lower().strip(),
                    "calories":     nutrients.get("Energy", 0),
                    "protein_g":    nutrients.get("Protein", 0),
                    "fat_g":        nutrients.get("Total lipid (fat)", 0),
                    "carbs_g":      nutrients.get("Carbohydrate, by difference", 0),
                    "fiber_g":      nutrients.get("Fiber, total dietary", 0),
                    "sugar_g":      nutrients.get("Sugars, total including NLEA", 0),
                    "source":       "USDA",
                })
        except Exception as e:
            print(f"Error fetching {term}: {e}")

    return foods


def fetch_open_food_facts(limit=5000):
    """
    Downloads a sample of Open Food Facts data.
    Full dataset is 9GB — we use their API to get a manageable sample.
    """
    print("Fetching Open Food Facts data...")
    foods = []

    # Use their search API for specific food categories
    categories = [
        "breakfast cereals", "bread", "rice", "chicken",
        "beef", "fish", "vegetables", "fruits", "dairy",
        "legumes", "pasta", "snacks", "beverages", "eggs",
    ]

    for category in categories:
        url = (
            f"https://world.openfoodfacts.org/cgi/search.pl"
            f"?action=process&tagtype_0=categories"
            f"&tag_contains_0=contains&tag_0={category}"
            f"&fields=product_name,nutriments"
            f"&json=1&page_size=50"
        )

        try:
            resp  = requests.get(url, timeout=15)
            data  = resp.json()
            prods = data.get("products", [])

            for prod in prods:
                name      = prod.get("product_name", "").lower().strip()
                nutriments = prod.get("nutriments", {})

                if not name:
                    continue

                foods.append({
                    "food_name": name,
                    "calories":  nutriments.get("energy-kcal_100g", 0),
                    "protein_g": nutriments.get("proteins_100g",    0),
                    "fat_g":     nutriments.get("fat_100g",         0),
                    "carbs_g":   nutriments.get("carbohydrates_100g", 0),
                    "fiber_g":   nutriments.get("fiber_100g",       0),
                    "sugar_g":   nutriments.get("sugars_100g",      0),
                    "source":    "OpenFoodFacts",
                })
        except Exception as e:
            print(f"Error fetching {category}: {e}")

    return foods


def add_african_foods():
    """
    Manually curated dataset of common African/Ghanaian foods.
    Values are per 100g serving based on FAO West African
    Food Composition Table and published nutrition research.
    """
    return [
        {"food_name": "jollof rice",       "calories": 150, "protein_g": 3.5,
         "fat_g": 3.2, "carbs_g": 27.0, "fiber_g": 0.6, "sugar_g": 0.5,
         "source": "FAO_African"},
        {"food_name": "fufu",              "calories": 267, "protein_g": 1.0,
         "fat_g": 0.4, "carbs_g": 64.0, "fiber_g": 2.0, "sugar_g": 1.0,
         "source": "FAO_African"},
        {"food_name": "banku",             "calories": 173, "protein_g": 3.8,
         "fat_g": 0.8, "carbs_g": 37.0, "fiber_g": 1.5, "sugar_g": 0.4,
         "source": "FAO_African"},
        {"food_name": "kenkey",            "calories": 165, "protein_g": 3.2,
         "fat_g": 0.6, "carbs_g": 36.0, "fiber_g": 1.8, "sugar_g": 0.3,
         "source": "FAO_African"},
        {"food_name": "kelewele",          "calories": 180, "protein_g": 1.2,
         "fat_g": 7.0, "carbs_g": 28.0, "fiber_g": 2.0, "sugar_g": 12.0,
         "source": "FAO_African"},
        {"food_name": "waakye",            "calories": 160, "protein_g": 6.0,
         "fat_g": 2.5, "carbs_g": 28.0, "fiber_g": 3.5, "sugar_g": 0.8,
         "source": "FAO_African"},
        {"food_name": "groundnut soup",    "calories": 210, "protein_g": 12.0,
         "fat_g": 14.0, "carbs_g": 8.0, "fiber_g": 2.5, "sugar_g": 2.0,
         "source": "FAO_African"},
        {"food_name": "palm nut soup",     "calories": 185, "protein_g": 8.0,
         "fat_g": 12.0, "carbs_g": 9.0, "fiber_g": 2.0, "sugar_g": 1.5,
         "source": "FAO_African"},
        {"food_name": "fried plantain",    "calories": 196, "protein_g": 1.0,
         "fat_g": 8.0, "carbs_g": 32.0, "fiber_g": 2.3, "sugar_g": 14.0,
         "source": "FAO_African"},
        {"food_name": "omo tuo",           "calories": 130, "protein_g": 2.5,
         "fat_g": 0.3, "carbs_g": 29.0, "fiber_g": 0.5, "sugar_g": 0.2,
         "source": "FAO_African"},
        {"food_name": "kontomire stew",    "calories": 95,  "protein_g": 5.0,
         "fat_g": 6.0, "carbs_g": 7.0,  "fiber_g": 3.0, "sugar_g": 1.0,
         "source": "FAO_African"},
        {"food_name": "tilapia fish",      "calories": 128, "protein_g": 26.0,
         "fat_g": 2.7, "carbs_g": 0.0,  "fiber_g": 0.0, "sugar_g": 0.0,
         "source": "FAO_African"},
        {"food_name": "boiled yam",        "calories": 118, "protein_g": 1.5,
         "fat_g": 0.2, "carbs_g": 27.9, "fiber_g": 4.1, "sugar_g": 0.5,
         "source": "FAO_African"},
        {"food_name": "shito",             "calories": 120, "protein_g": 3.0,
         "fat_g": 9.0, "carbs_g": 7.0,  "fiber_g": 1.5, "sugar_g": 2.0,
         "source": "FAO_African"},
        {"food_name": "sobolo",            "calories": 45,  "protein_g": 0.5,
         "fat_g": 0.1, "carbs_g": 11.0, "fiber_g": 0.3, "sugar_g": 9.0,
         "source": "FAO_African"},
        {"food_name": "eba",               "calories": 148, "protein_g": 1.0,
         "fat_g": 0.2, "carbs_g": 35.0, "fiber_g": 1.8, "sugar_g": 0.3,
         "source": "FAO_African"},
        {"food_name": "egusi soup",        "calories": 230, "protein_g": 14.0,
         "fat_g": 16.0, "carbs_g": 8.0, "fiber_g": 2.0, "sugar_g": 1.0,
         "source": "FAO_African"},
        {"food_name": "suya",              "calories": 220, "protein_g": 25.0,
         "fat_g": 11.0, "carbs_g": 4.0, "fiber_g": 0.5, "sugar_g": 1.0,
         "source": "FAO_African"},
        {"food_name": "roasted plantain",  "calories": 150, "protein_g": 1.3,
         "fat_g": 0.4, "carbs_g": 38.0, "fiber_g": 2.5, "sugar_g": 17.0,
         "source": "FAO_African"},
        {"food_name": "peanuts",           "calories": 567, "protein_g": 25.8,
         "fat_g": 49.2, "carbs_g": 16.1, "fiber_g": 8.5, "sugar_g": 4.0,
         "source": "FAO_African"},
    ]


def prepare_dataset():
    """
    Main function — fetches all data sources,
    cleans them, and saves to CSV for training.
    """
    print("=== Preparing HealthTrack Nutrition Dataset ===\n")

    # 1. African foods (local, hand-curated)
    african = add_african_foods()
    print(f"African foods: {len(african)} entries")

    # 2. USDA foods
    usda_terms = [
        "rice", "chicken breast", "beef", "egg", "milk", "bread",
        "apple", "banana", "orange", "broccoli", "carrot", "potato",
        "salmon", "tuna", "yogurt", "cheese", "butter", "oil",
        "pasta", "oats", "corn", "beans", "lentils", "tofu",
        "avocado", "tomato", "onion", "garlic", "spinach", "lettuce",
    ]
    usda = fetch_usda_foods(usda_terms)
    print(f"USDA foods: {len(usda)} entries")

    # 3. Open Food Facts
    off = fetch_open_food_facts()
    print(f"Open Food Facts: {len(off)} entries")

    # Combine all sources
    all_foods = african + usda + off
    df        = pd.DataFrame(all_foods)

    # Clean data
    df = df.dropna(subset=["food_name"])
    df = df[df["calories"] > 0]          # Remove zero-calorie entries
    df = df[df["calories"] < 1000]       # Remove unrealistic values
    df = df.drop_duplicates(subset=["food_name"])
    df = df.reset_index(drop=True)

    # Fill missing values with 0
    numeric_cols = ["calories","protein_g","fat_g","carbs_g","fiber_g","sugar_g"]
    df[numeric_cols] = df[numeric_cols].fillna(0)

    # Save
    os.makedirs("data", exist_ok=True)
    df.to_csv("data/nutrition_dataset.csv", index=False)
    print(f"\n✅ Dataset saved: {len(df)} total food entries")
    print(df.head(10))
    return df


if __name__ == "__main__":
    prepare_dataset()