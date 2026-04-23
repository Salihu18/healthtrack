"""
Mini LLM for food nutrition prediction.

Architecture:
- Input:  food name converted to token embeddings
- Model:  Transformer encoder with self-attention
- Output: 6 nutrition values (calories, protein, fat, carbs, fiber, sugar)

This is a simplified transformer — small enough to train on a laptop
but demonstrates all the core LLM concepts for academic purposes.
"""

import torch
import torch.nn as nn
import math


class FoodTokenizer:
    """
    Converts food name strings into integer token sequences.
    Each character becomes a token (character-level tokenizer).
    
    Example: "jollof rice" → [10, 15, 12, 12, 15, 6, ...]
    
    In real LLMs (GPT, Claude), tokenizers use subwords (BPE),
    but character-level is easier to understand and implement.
    """

    def __init__(self, vocab_size=128):
        self.vocab_size = vocab_size
        self.max_length = 50   # Maximum food name length

    def encode(self, text: str) -> torch.Tensor:
        """Convert food name string to tensor of ASCII values."""
        text    = text.lower().strip()[:self.max_length]
        tokens  = [ord(c) % self.vocab_size for c in text]
        # Pad to max_length with zeros
        padding = [0] * (self.max_length - len(tokens))
        tokens  = tokens + padding
        return torch.tensor(tokens, dtype=torch.long)

    def encode_batch(self, texts: list) -> torch.Tensor:
        """Encode a list of food names into a batch tensor."""
        return torch.stack([self.encode(t) for t in texts])


class PositionalEncoding(nn.Module):
    """
    Adds position information to embeddings.
    
    Without this, the model cannot tell if "rice jollof"
    is different from "jollof rice" — order matters!
    
    This uses sine and cosine waves at different frequencies
    to encode each position uniquely (original transformer paper).
    """

    def __init__(self, d_model: int, max_len: int = 50):
        super().__init__()

        # Create position encoding matrix
        pe       = torch.zeros(max_len, d_model)
        position = torch.arange(0, max_len).unsqueeze(1).float()
        div_term = torch.exp(
            torch.arange(0, d_model, 2).float()
            * (-math.log(10000.0) / d_model)
        )

        # Sine for even dimensions, cosine for odd
        pe[:, 0::2] = torch.sin(position * div_term)
        pe[:, 1::2] = torch.cos(position * div_term)
        pe          = pe.unsqueeze(0)  # Add batch dimension

        # Register as buffer (not a trainable parameter)
        self.register_buffer("pe", pe)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return x + self.pe[:, :x.size(1)]


class SelfAttention(nn.Module):
    """
    Multi-head self-attention mechanism.
    
    This is the CORE of what makes LLMs powerful.
    Each token looks at every other token and decides
    how much attention to pay to it.
    
    Example: in "grilled chicken breast",
    "grilled" pays high attention to "chicken" and "breast"
    because they determine the nutrition together.
    
    Q = Query  (what am I looking for?)
    K = Key    (what do I have to offer?)
    V = Value  (what information do I carry?)
    
    Attention(Q,K,V) = softmax(QK^T / sqrt(d_k)) * V
    """

    def __init__(self, d_model: int, num_heads: int):
        super().__init__()
        assert d_model % num_heads == 0

        self.d_model   = d_model
        self.num_heads = num_heads
        self.d_k       = d_model // num_heads

        # Linear projections for Q, K, V
        self.W_q = nn.Linear(d_model, d_model)
        self.W_k = nn.Linear(d_model, d_model)
        self.W_v = nn.Linear(d_model, d_model)
        self.W_o = nn.Linear(d_model, d_model)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        batch_size = x.size(0)

        # Project to Q, K, V
        Q = self.W_q(x)
        K = self.W_k(x)
        V = self.W_v(x)

        # Reshape for multi-head attention
        # Shape: (batch, heads, seq_len, d_k)
        Q = Q.view(batch_size, -1, self.num_heads, self.d_k).transpose(1, 2)
        K = K.view(batch_size, -1, self.num_heads, self.d_k).transpose(1, 2)
        V = V.view(batch_size, -1, self.num_heads, self.d_k).transpose(1, 2)

        # Scaled dot-product attention
        scores   = torch.matmul(Q, K.transpose(-2, -1)) / math.sqrt(self.d_k)
        attn     = torch.softmax(scores, dim=-1)
        context  = torch.matmul(attn, V)

        # Reshape back
        context = context.transpose(1, 2).contiguous()
        context = context.view(batch_size, -1, self.d_model)

        return self.W_o(context)


class TransformerBlock(nn.Module):
    """
    One transformer block = Self-Attention + Feed Forward Network.
    
    Real LLMs stack many of these:
    GPT-2 small  = 12 blocks
    GPT-3        = 96 blocks
    Our mini LLM = 2 blocks (enough to learn nutrition patterns)
    """

    def __init__(self, d_model: int, num_heads: int, ff_dim: int,
                 dropout: float = 0.1):
        super().__init__()

        self.attention  = SelfAttention(d_model, num_heads)
        self.norm1      = nn.LayerNorm(d_model)
        self.norm2      = nn.LayerNorm(d_model)
        self.dropout    = nn.Dropout(dropout)

        # Feed-forward network
        self.ff = nn.Sequential(
            nn.Linear(d_model, ff_dim),
            nn.ReLU(),
            nn.Dropout(dropout),
            nn.Linear(ff_dim, d_model),
        )

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        # Self-attention with residual connection
        x = self.norm1(x + self.dropout(self.attention(x)))
        # Feed-forward with residual connection
        x = self.norm2(x + self.dropout(self.ff(x)))
        return x


class FoodNutritionLLM(nn.Module):
    """
    Complete Mini LLM for food nutrition prediction.
    
    Input:  food name string (e.g. "jollof rice with chicken")
    Output: [calories, protein, fat, carbs, fiber, sugar]
    
    Architecture:
    1. Tokenize food name → integer tokens
    2. Embed tokens → dense vectors
    3. Add positional encoding
    4. Pass through transformer blocks (self-attention)
    5. Pool the output (take mean across sequence)
    6. Project to 6 nutrition values
    """

    def __init__(
        self,
        vocab_size:  int = 128,
        d_model:     int = 128,
        num_heads:   int = 4,
        num_layers:  int = 2,
        ff_dim:      int = 256,
        max_len:     int = 50,
        dropout:     float = 0.1,
        num_outputs: int = 6,  # calories, protein, fat, carbs, fiber, sugar
    ):
        super().__init__()

        self.tokenizer = FoodTokenizer(vocab_size)

        # Token embedding — maps each token ID to a dense vector
        self.embedding = nn.Embedding(vocab_size, d_model, padding_idx=0)

        # Positional encoding
        self.pos_encoding = PositionalEncoding(d_model, max_len)

        self.dropout = nn.Dropout(dropout)

        # Stack of transformer blocks
        self.transformer_blocks = nn.ModuleList([
            TransformerBlock(d_model, num_heads, ff_dim, dropout)
            for _ in range(num_layers)
        ])

        # Output head — maps final representation to nutrition values
        self.output_head = nn.Sequential(
            nn.Linear(d_model, 64),
            nn.ReLU(),
            nn.Dropout(dropout),
            nn.Linear(64, num_outputs),
            nn.ReLU(),  # Nutrition values are always >= 0
        )

    def forward(self, token_ids: torch.Tensor) -> torch.Tensor:
        """
        Forward pass through the model.
        token_ids shape: (batch_size, seq_len)
        output shape:    (batch_size, 6)
        """

        # 1. Embed tokens
        x = self.embedding(token_ids)      # (batch, seq, d_model)

        # 2. Add position encoding
        x = self.pos_encoding(x)
        x = self.dropout(x)

        # 3. Pass through transformer blocks
        for block in self.transformer_blocks:
            x = block(x)                  # (batch, seq, d_model)

        # 4. Mean pooling over sequence dimension
        x = x.mean(dim=1)                 # (batch, d_model)

        # 5. Project to output
        return self.output_head(x)        # (batch, 6)

    def predict(self, food_name: str, device: str = "cpu") -> dict:
        """
        Predict nutrition for a single food name.
        Returns a dict with all nutrition values.
        """
        self.eval()
        with torch.no_grad():
            tokens = self.tokenizer.encode(food_name).unsqueeze(0).to(device)
            output = self.forward(tokens).squeeze(0).cpu().numpy()

        return {
            "food_name": food_name,
            "calories":  round(float(output[0]), 1),
            "protein_g": round(float(output[1]), 1),
            "fat_g":     round(float(output[2]), 1),
            "carbs_g":   round(float(output[3]), 1),
            "fiber_g":   round(float(output[4]), 1),
            "sugar_g":   round(float(output[5]), 1),
        }