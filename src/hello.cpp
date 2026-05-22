#include <emscripten/bind.h>

int add(int a, int b) {
    return a + b;
}

std::string greet(const std::string& name) {
    return "Hello, " + name + "!";
}

EMSCRIPTEN_BINDINGS(hello_module) {
    emscripten::function("add", &add);
    emscripten::function("greet", &greet);
}
