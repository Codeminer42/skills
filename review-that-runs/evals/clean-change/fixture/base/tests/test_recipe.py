import unittest
from fractions import Fraction

from portions.recipe import Ingredient, Recipe


class RecipeTest(unittest.TestCase):
    def test_holds_exact_amounts(self):
        recipe = Recipe("Pancakes", 4, (Ingredient("flour", Fraction(3, 2), "cup"),))
        self.assertEqual(recipe.ingredients[0].amount, Fraction(3, 2))

    def test_serves_at_least_one(self):
        with self.assertRaises(ValueError):
            Recipe("Air", 0, ())
