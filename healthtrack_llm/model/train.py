"""
Training script for the FoodNutritionLLM.

This script:
1. Loads the nutrition dataset
2. Normalizes the nutrition values
3. Trains the model using MSE loss
4. Saves the trained model and normalization stats
"""

import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import Dataset, DataLoader
import pandas as pd
import numpy as np
import json
import os
from model import FoodNutritionLLM, FoodTokenizer

# ── Hyperparameters ───────────────────────────────────────────────────────────
EPOCHS      = 100
BATCH_SIZE  = 32
LR          = 0.001
D_MODEL     = 128
NUM_HEADS   = 4
NUM_LAYERS  = 2
FF_DIM      = 256
DROPOUT     = 0.1
DEVICE      = "cuda" if torch.cuda.is_available() else "cpu"

print(f"Training on: {DEVICE}")


class FoodDataset(Dataset):
    """
    PyTorch Dataset for food nutrition data.
    
    Loads the CSV, tokenizes food names,
    and normalizes nutrition values to 0-1 range
    so the model trains more stably.
    """

    def __init__(self, csv_path: str):
        df = pd.read_csv(csv_path)

        self.food_names = df["food_name"].tolist()
        self.tokenizer  = FoodTokenizer()

        # Nutrition columns we want to predict
        self.nutrition_cols = [
            "calories", "protein_g", "fat_g",
            "carbs_g",  "fiber_g",   "sugar_g",
        ]

        # Get raw nutrition values
        nutrition = df[self.nutrition_cols].values.astype(np.float32)

        # Normalize: store max values for later denormalization
        self.nutrition_max = nutrition.max(axis=0) + 1e-8
        self.nutrition_norm = nutrition / self.nutrition_max

        # Save normalization stats for the API to use
        stats = {col: float(self.nutrition_max[i])
                 for i, col in enumerate(self.nutrition_cols)}
        with open("model/normalization_stats.json", "w") as f:
            json.dump(stats, f, indent=2)

        print(f"Dataset loaded: {len(self.food_names)} foods")
        print(f"Normalization stats: {stats}")

    def __len__(self):
        return len(self.food_names)

    def __getitem__(self, idx):
        tokens    = self.tokenizer.encode(self.food_names[idx])
        nutrition = torch.tensor(
            self.nutrition_norm[idx], dtype=torch.float32)
        return tokens, nutrition


def train():
    """Main training function."""

    # Load dataset
    dataset    = FoodDataset("data/nutrition_dataset.csv")
    train_size = int(0.8 * len(dataset))
    val_size   = len(dataset) - train_size

    train_set, val_set = torch.utils.data.random_split(
        dataset, [train_size, val_size])

    train_loader = DataLoader(train_set, batch_size=BATCH_SIZE, shuffle=True)
    val_loader   = DataLoader(val_set,   batch_size=BATCH_SIZE, shuffle=False)

    # Initialize model
    model = FoodNutritionLLM(
        d_model=D_MODEL, num_heads=NUM_HEADS,
        num_layers=NUM_LAYERS, ff_dim=FF_DIM, dropout=DROPOUT,
    ).to(DEVICE)

    total_params = sum(p.numel() for p in model.parameters())
    print(f"\nModel parameters: {total_params:,}")
    print(f"Training samples: {train_size}")
    print(f"Validation samples: {val_size}\n")

    # Loss and optimizer
    criterion = nn.MSELoss()
    optimizer = optim.Adam(model.parameters(), lr=LR)
    scheduler = optim.lr_scheduler.ReduceLROnPlateau(
        optimizer, patience=10, factor=0.5)

    best_val_loss = float("inf")

    # Training loop
    for epoch in range(EPOCHS):
        # ── Training phase ─────────────────────────────────
        model.train()
        train_loss = 0.0

        for tokens, nutrition in train_loader:
            tokens    = tokens.to(DEVICE)
            nutrition = nutrition.to(DEVICE)

            optimizer.zero_grad()
            output = model(tokens)
            loss   = criterion(output, nutrition)
            loss.backward()

            # Gradient clipping prevents exploding gradients
            nn.utils.clip_grad_norm_(model.parameters(), max_norm=1.0)

            optimizer.step()
            train_loss += loss.item()

        train_loss /= len(train_loader)

        # ── Validation phase ───────────────────────────────
        model.eval()
        val_loss = 0.0

        with torch.no_grad():
            for tokens, nutrition in val_loader:
                tokens    = tokens.to(DEVICE)
                nutrition = nutrition.to(DEVICE)
                output    = model(tokens)
                val_loss  += criterion(output, nutrition).item()

        val_loss /= len(val_loader)
        scheduler.step(val_loss)

        # Save best model
        if val_loss < best_val_loss:
            best_val_loss = val_loss
            os.makedirs("model", exist_ok=True)
            torch.save(model.state_dict(), "model/food_model.pth")

        if (epoch + 1) % 10 == 0:
            print(f"Epoch {epoch+1:3d}/{EPOCHS} | "
                  f"Train Loss: {train_loss:.4f} | "
                  f"Val Loss: {val_loss:.4f} | "
                  f"LR: {optimizer.param_groups[0]['lr']:.6f}")

    print(f"\n✅ Training complete. Best val loss: {best_val_loss:.4f}")
    print("Model saved to model/food_model.pth")


if __name__ == "__main__":
    train()