import '../models/question.dart';

final List<Question> allQuestions = [

  // QUANTITATIVE
  Question(
    questionText: 'A train travels 60 km in 1 hour. How far in 2.5 hours?',
    options: ['120 km', '150 km', '180 km', '90 km'],
    correctIndex: 1,
    category: 'quant',
  ),
  Question(
    questionText: 'Buy for ₹200, sell for ₹250. Profit percentage?',
    options: ['20%', '25%', '30%', '15%'],
    correctIndex: 1,
    category: 'quant',
  ),
  Question(
    questionText: 'What is 15% of 400?',
    options: ['45', '60', '75', '80'],
    correctIndex: 1,
    category: 'quant',
  ),
  Question(
    questionText: 'A and B finish a job in 12 days. A alone takes 20 days. B alone?',
    options: ['30 days', '40 days', '25 days', '35 days'],
    correctIndex: 0,
    category: 'quant',
  ),
  Question(
    questionText: 'Boys to girls ratio is 3:2. Total 40 students. How many boys?',
    options: ['20', '24', '16', '18'],
    correctIndex: 1,
    category: 'quant',
  ),
  Question(
    questionText: 'Simple interest on ₹1000 at 10% per year for 2 years?',
    options: ['₹100', '₹150', '₹200', '₹250'],
    correctIndex: 2,
    category: 'quant',
  ),
  Question(
    questionText: 'Speed doubles. Time to cover same distance?',
    options: ['Doubles', 'Same', 'Halves', 'Triples'],
    correctIndex: 2,
    category: 'quant',
  ),
  Question(
    questionText: 'Loss of 10% on cost price ₹500. Selling price?',
    options: ['₹400', '₹450', '₹480', '₹550'],
    correctIndex: 1,
    category: 'quant',
  ),

  // LOGICAL REASONING
  Question(
    questionText: 'Next number: 2, 6, 12, 20, 30, ?',
    options: ['40', '42', '44', '36'],
    correctIndex: 1,
    category: 'logic',
  ),
  Question(
    questionText: 'All Roses are Flowers. All Flowers are Plants. So?',
    options: [
      'All plants are roses',
      'All roses are plants',
      'Some plants are not flowers',
      'None of these'
    ],
    correctIndex: 1,
    category: 'logic',
  ),
  Question(
    questionText: 'A is father of B. B is sister of C. A is related to C as?',
    options: ['Uncle', 'Father', 'Grandfather', 'Brother'],
    correctIndex: 1,
    category: 'logic',
  ),
  Question(
    questionText: 'Book : Library :: Patient : ?',
    options: ['Doctor', 'Medicine', 'Hospital', 'Nurse'],
    correctIndex: 2,
    category: 'logic',
  ),
  Question(
    questionText: 'Odd one out: Triangle, Circle, Rectangle, Cube',
    options: ['Triangle', 'Circle', 'Rectangle', 'Cube'],
    correctIndex: 3,
    category: 'logic',
  ),
  Question(
    questionText: 'If MANGO = OCPIQ, then APPLE = ?',
    options: ['CRRNG', 'CQQNG', 'BQPLF', 'CRRNF'],
    correctIndex: 0,
    category: 'logic',
  ),
  Question(
    questionText: 'Clock shows 3:15. Angle between hour and minute hands?',
    options: ['0°', '7.5°', '15°', '22.5°'],
    correctIndex: 1,
    category: 'logic',
  ),
  Question(
    questionText: 'Pointing to photo: "She is mother of my father\'s only son." Who?',
    options: ['Sister', 'Wife', 'Mother', 'Daughter'],
    correctIndex: 2,
    category: 'logic',
  ),

  // ENGLISH
  Question(
    questionText: 'Synonym of "Abundant":',
    options: ['Scarce', 'Plentiful', 'Empty', 'Rare'],
    correctIndex: 1,
    category: 'english',
  ),
  Question(
    questionText: 'Fill in: She ____ to the market yesterday.',
    options: ['go', 'goes', 'went', 'going'],
    correctIndex: 2,
    category: 'english',
  ),
  Question(
    questionText: 'Antonym of "Confident":',
    options: ['Bold', 'Unsure', 'Proud', 'Sure'],
    correctIndex: 1,
    category: 'english',
  ),
  Question(
    questionText: 'Which is grammatically correct?',
    options: [
      'He don\'t know.',
      'They goes to school.',
      'She doesn\'t like mangoes.',
      'I are happy.',
    ],
    correctIndex: 2,
    category: 'english',
  ),
  Question(
    questionText: 'Correct spelling:',
    options: ['Accomodate', 'Accommodate', 'Acommodate', 'Acomodate'],
    correctIndex: 1,
    category: 'english',
  ),
  Question(
    questionText: '"Bite the bullet" means:',
    options: [
      'To shoot someone',
      'To eat something hard',
      'To endure a painful situation',
      'To be very brave'
    ],
    correctIndex: 2,
    category: 'english',
  ),
  Question(
    questionText: 'Correctly punctuated:',
    options: [
      'Its a wonderful day.',
      'It\'s a wonderful day.',
      'Its\' a wonderful day.',
      'It\'s a, wonderful day.',
    ],
    correctIndex: 1,
    category: 'english',
  ),
  Question(
    questionText: 'Passive voice of "She wrote a letter":',
    options: [
      'A letter is written by her.',
      'A letter was written by her.',
      'A letter has been written by her.',
      'A letter will be written by her.',
    ],
    correctIndex: 1,
    category: 'english',
  ),
];

List<Question> getQuestionsByCategory(String category) {
  return allQuestions.where((q) => q.topic == category).toList();
}

List<Question> getBossQuestionSet({int count = 30}) {
  final source = List<Question>.from(allQuestions);
  final result = <Question>[];
  while (result.length < count) {
    source.shuffle();
    result.addAll(source);
  }
  return result.take(count).toList();
}

List<Question> getBossQuestions() {
  return getBossQuestionSet(count: 30);
}