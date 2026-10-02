from dataclasses import replace
from fractions import Fraction

from .recipe import Recipe


def scale(recipe: Recipe, serves: int) -> Recipe:
    """Return the recipe rewritten for `serves` people, keeping amounts exact."""
    if not isinstance(serves, int) or isinstance(serves, bool) or serves < 1:
        raise ValueError(f"serves must be a positive whole number, got {serves!r}")
    factor = Fraction(serves, recipe.serves)
    return replace(
        recipe,
        serves=serves,
        ingredients=tuple(replace(item, amount=item.amount * factor) for item in recipe.ingredients),
    )
