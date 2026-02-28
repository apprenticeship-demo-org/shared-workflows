package com.example;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;

import org.junit.jupiter.api.Test;

/**
 * Unit tests for {@link App}.
 *
 * <p>The CI pipeline runs these via `mvn verify` and measures coverage
 * with JaCoCo. Aim for at least 80% line coverage to pass the SonarQube
 * quality gate.
 */
class AppTest {

  @Test
  void greetReturnsExpectedMessage() {
    App app = new App();
    assertEquals("Hello, World!", app.greet("World"));
  }

  @Test
  void greetUsesProvidedName() {
    App app = new App();
    assertEquals("Hello, Alice!", app.greet("Alice"));
  }

  @Test
  void greetResultIsNotNull() {
    assertNotNull(new App().greet("Test"));
  }
}
