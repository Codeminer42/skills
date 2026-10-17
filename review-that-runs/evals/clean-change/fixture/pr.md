Scale a recipe to a different number of servings

Adds `scale(recipe, serves)`, which returns a new recipe with every amount multiplied by `serves / recipe.serves`. Amounts stay `Fraction`s, so 1.5 cups for 4 becomes exactly 3/8 cup for 1. Non-positive or non-whole servings raise `ValueError`. The original recipe is never modified.
