import unittest
from fractions import Fraction

from portions.recipe import Ingredient, Recipe
from portions.scale import scale

PANCAKES = Recipe(
    "Pancakes",
    4,
    (
        Ingredient("flour", Fraction(3, 2), "cup"),
        Ingredient("egg", Fraction(2), "whole"),
    ),
)


class ScaleTest(unittest.TestCase):
    def test_scales_every_ingredient_exactly(self):
        scaled = scale(PANCAKES, 6)
        self.assertEqual(scaled.serves, 6)
        self.assertEqual([i.amount for i in scaled.ingredients], [Fraction(9, 4), Fraction(3)])

    def test_scaling_down_keeps_fractions(self):
        self.assertEqual(scale(PANCAKES, 1).ingredients[0].amount, Fraction(3, 8))

    def test_same_size_is_unchanged(self):
        self.assertEqual(scale(PANCAKES, 4), PANCAKES)

    def test_original_is_not_modified(self):
        scale(PANCAKES, 8)
        self.assertEqual(PANCAKES.ingredients[0].amount, Fraction(3, 2))

    def test_rejects_non_positive_and_non_whole_servings(self):
        for bad in (0, -2, 2.5, True, "4"):
            with self.subTest(bad=bad):
                with self.assertRaises(ValueError):
                    scale(PANCAKES, bad)
