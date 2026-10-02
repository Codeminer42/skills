from dataclasses import dataclass
from fractions import Fraction


@dataclass(frozen=True)
class Ingredient:
    name: str
    amount: Fraction
    unit: str


@dataclass(frozen=True)
class Recipe:
    title: str
    serves: int
    ingredients: tuple[Ingredient, ...]

    def __post_init__(self):
        if self.serves < 1:
            raise ValueError(f"a recipe serves at least one person, got {self.serves!r}")
