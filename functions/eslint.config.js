module.exports = [
  {
    files: ["src/**/*.js", "test/**/*.js"],
    languageOptions: {
      ecmaVersion: 2023,
      sourceType: "commonjs",
      globals: {
        __dirname: "readonly",
        fetch: "readonly",
        module: "readonly",
        process: "readonly",
        require: "readonly",
      },
    },
    rules: {
      "no-unused-vars": ["error", {argsIgnorePattern: "^_"}],
      "no-undef": "error",
      "semi": ["error", "always"],
    },
  },
];
