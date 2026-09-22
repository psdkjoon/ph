double solve(List<String> equation) {
  equation = List<String>.from(equation);
  int index = 0;
  while (index < equation.length) {
    if (equation[index] == '(') {
      int depth = 1;
      int checker = index + 1;
      while (checker < equation.length && depth > 0) {
        if (equation[checker] == '(') depth++;
        if (equation[checker] == ')') depth--;
        if (depth == 0) break;
        checker++;
      }
      double parenthesesAnswer = solve(equation.sublist(index + 1, checker));
      equation.replaceRange(index, checker + 1, [parenthesesAnswer.toString()]);
      index = 0;
      continue;
    }
    index++;
  }

  const operators = ['//', '/', '-', '+', '*', '%', '^'];
  const polarity = ['-', '+'];

  if (polarity.contains(equation[0])) {
    final merged = (double.parse(equation[1]) *
            (equation[0] == '-' ? -1 : 1))
        .toString();
    equation.replaceRange(0, 2, [merged]);
  }

  index = 1;
  while (index < equation.length) {
    if (polarity.contains(equation[index]) &&
        operators.contains(equation[index - 1])) {
      final merged = (double.parse(equation[index + 1]) *
              (equation[index] == '-' ? -1 : 1))
          .toString();
      equation.replaceRange(index, index + 2, [merged]);
    } else {
      index++;
    }
  }
  applyLevel(['^'], equation);
  applyLevel(['*', '/', '//', '%'], equation);
  applyLevel(['+', '-'], equation);

  return double.parse(equation[0]);
}

void applyLevel(List<String> ops, List<String> equation) {
  int i = 1;
  while (i < equation.length) {
    if (ops.contains(equation[i])) {
      final a = double.parse(equation[i - 1]);
      final b = double.parse(equation[i + 1]);
      double result;
      switch (equation[i]) {
        case '+':
          result = a + b;
          break;
        case '-':
          result = a - b;
          break;
        case '*':
          result = a * b;
          break;
        case '/':
          result = a / b;
          break;
        case '//':
          result = (a / b).toInt().toDouble();
          break;
        case '%':
          result = a % b;
          break;
        case '^':
          result = power(a, b);
          break;
        default:
          throw StateError('unknown operator ${equation[i]}');
      }
      equation.replaceRange(i - 1, i + 2, [result.toString()]);
      i = 1;
    } else {
      i++;
    }
  }
}

double power(double base, double exponent) {
  if (exponent < 0) return 1 / power(base, -exponent);
  double answer = 1.0;
  for (var i = 0; i < exponent; i++) {
    answer *= base;
  }
  return answer;
}
