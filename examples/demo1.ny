import math

class Student:
    def init(self, name, grades):
        self.name = name
        self.grades = grades
    def average(self):
        return self.grades.reduce(lambda a, b: a + b, 0) / len(self.grades)
    def letter_grade(self):
        var avg = self.average()
        if avg >= 90:
            return "A"
        elif avg >= 80:
            return "B"
        else:
            return "C"

var s = Student("Alice", [95, 87, 92, 88])
print s.average()
print s.letter_grade()
