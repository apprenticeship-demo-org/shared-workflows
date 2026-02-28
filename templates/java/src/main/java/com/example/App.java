package com.example;

/**
 * Entry point for the application.
 *
 * <p>Replace this class with your own implementation.
 * The class name and package must match the groupId/artifactId in pom.xml.
 */
public class App {

  /**
   * Returns a greeting for the given name.
   *
   * @param name the name to greet
   * @return a greeting string
   */
  public String greet(String name) {
    return "Hello, " + name + "!";
  }

  /**
   * Application entry point.
   *
   * @param args command-line arguments (unused)
   */
  public static void main(String[] args) {
    System.out.println(new App().greet("World"));
  }
}
