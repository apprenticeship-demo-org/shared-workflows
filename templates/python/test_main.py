"""Tests for main.py.

The CI pipeline runs these via:
    pytest --cov=. --cov-report=xml

The resulting coverage.xml is uploaded to SonarQube. Aim for at least
80% line coverage to pass the quality gate.
"""
from main import greet


def test_greet_returns_expected_message():
    assert greet("World") == "Hello, World!"


def test_greet_uses_provided_name():
    assert greet("Alice") == "Hello, Alice!"


def test_greet_returns_string():
    assert isinstance(greet("Test"), str)
