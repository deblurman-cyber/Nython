var pass_n = 0
var fail_n = 0
def t(name, actual, expected):
    if str(actual) == str(expected):
        pass_n = pass_n + 1
    else:
        fail_n = fail_n + 1
        print "FAIL: " + name + " got=" + str(actual) + " exp=" + str(expected)

print "=== THREADING ==="
import threading
var mtx = mutex_create()
t("mutex_lock", mutex_lock(mtx), true)
t("mutex_unlock", mutex_unlock(mtx), true)

print "=== LINUX COMMANDS ==="
t("shell", shell("echo nython"), "nython")
t("pwd_len", len(pwd()) > 0, true)
write("/tmp/ny_sys_test.txt", "system test content")
t("cat", cat("/tmp/ny_sys_test.txt"), "system test content")
t("exists_t", exists("/tmp/ny_sys_test.txt"), true)
t("exists_f", exists("/tmp/no_such_file_xyz"), false)
t("env", len(env("HOME")) > 0, true)
var files = ls("/tmp")
t("ls_type", type(files), "list")
t("ls_nonempty", len(files) > 0, true)

print "=== NYTORCH TENSORS ==="
import ai
var t1 = tensor([1.0, 2.0, 3.0, 4.0])
var t2 = tensor([5.0, 6.0, 7.0, 8.0])
t("t_add", str(tensor_add(t1, t2)), "[6, 8, 10, 12]")
t("t_sub", str(tensor_sub(t2, t1)), "[4, 4, 4, 4]")
t("t_mul", str(tensor_mul(t1, t2)), "[5, 12, 21, 32]")
t("t_dot", tensor_dot(t1, t2), 70)
t("t_sum", tensor_sum(t1), 10)
t("t_mean", tensor_mean(t1), 2.5)
t("t_max", tensor_max(t2), 8)
t("t_min", tensor_min(t1), 1)
t("t_scale", str(tensor_scale(t1, 2.0)), "[2, 4, 6, 8]")
t("t_apply", str(tensor_apply(t1, lambda x: x * x)), "[1, 4, 9, 16]")
t("zeros", str(zeros(3)), "[0, 0, 0]")
t("ones", str(ones(3)), "[1, 1, 1]")
t("random_len", len(random_tensor(5)), 5)

print "=== ACTIVATIONS ==="
t("relu_n", relu(-5), 0)
t("relu_p", relu(5), 5)
t("sigmoid_0", sigmoid(0), 0.5)
t("sigmoid_hi", sigmoid(100) > 0.99, true)
var probs = softmax(tensor([1.0, 2.0, 3.0]))
t("softmax_sum", tensor_sum(probs) > 0.99, true)

print "=== MATRIX OPS ==="
var A = matrix([[1.0, 2.0], [3.0, 4.0]])
var B = matrix([[5.0, 6.0], [7.0, 8.0]])
var C = mat_mul(A, B)
t("matmul_00", mat_get(C, 0, 0), 19)
t("matmul_01", mat_get(C, 0, 1), 22)
t("matmul_10", mat_get(C, 1, 0), 43)
t("matmul_11", mat_get(C, 1, 1), 50)
t("shape", str(mat_shape(A)), "[2, 2]")
var T = mat_transpose(matrix([[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]]))
t("trans_shape", str(mat_shape(T)), "[3, 2]")
t("trans_01", mat_get(T, 0, 1), 4)

print "=== KNOWLEDGE BASE ==="
kb_save("/tmp/ny_kb_test.txt", "Nython is a programming language")
t("kb_save", exists("/tmp/ny_kb_test.txt"), true)
t("kb_load", kb_load("/tmp/ny_kb_test.txt"), "Nython is a programming language")

print "=== NETWORK ==="
import net
t("url_enc", url_encode("hello world"), "hello%20world")
t("url_dec", url_decode("hello%20world"), "hello world")

print "=== CRYPTO ==="
import crypto
t("md5", md5("hello"), "5d41402abc4b2a76b9719d911017c592")
t("sha256_len", len(sha256("hello")), 64)

print ""
print "============================================"
print "  V14 SYSTEMS: " + str(pass_n) + " passed, " + str(fail_n) + " failed"
print "============================================"
