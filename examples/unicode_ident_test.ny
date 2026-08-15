var pass_n = 0
var fail_n = 0
def t(name, actual, expected):
    if str(actual) == str(expected):
        pass_n = pass_n + 1
    else:
        fail_n = fail_n + 1
        print "FAIL: " + name + " got=" + str(actual) + " exp=" + str(expected)

print "=== UNICODE IDENTIFIERS ==="
let 😍 = "smile"
t("emoji", 😍, "smile")

let π = 3.14159
t("pi", π, 3.14159)

let 你好 = "你好世界"
t("chinese", 你好, "你好世界")

let café = "coffee"
t("accent", café, "coffee")

let Ω = 100
t("omega", Ω, 100)

let α = 10
let β = 20
let γ = α + β
t("greek_math", γ, 30)

let 日本語 = "Japanese"
t("japanese", 日本語, "Japanese")

let données = [1, 2, 3]
t("french_list", len(données), 3)

class Véhicule:
    def init(self, nom):
        self.nom = nom
    def décrire(self):
        return "Je suis " + self.nom
var v = Véhicule("voiture")
t("unicode_class", v.décrire(), "Je suis voiture")

print ""
print "============================================"
print "  UNICODE: " + str(pass_n) + " passed, " + str(fail_n) + " failed"
print "============================================"
