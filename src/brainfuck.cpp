/*
Brainfuck.

Lab 2. Write a recursive descent parser for Brainfuck.
Lab 3. Write an interpreter for Brainfuck using Visitor.

References:

* http://en.wikipedia.org/wiki/Brainfuck
* http://www.cplusplus.com/reference/

If you have gcc:

----
gcc -o brainfuck.exe brainfuck.cpp
brainfuck.exe helloworld.bf
----
*/

#include <vector>
#include <iostream>
#include <fstream>

using namespace std;

/* Commands */
typedef enum { 
    INCREMENT, // +
    DECREMENT, // -
    SHIFT_LEFT, // <
    SHIFT_RIGHT, // >
    INPUT, // ,
    OUTPUT // .
} Command;

// Forward references. Silly C++!
class CommandNode;
class Loop;
class Program;

class Visitor {
    public:
        virtual void visit(const CommandNode * leaf) = 0;
        virtual void visit(const Loop * loop) = 0;
        virtual void visit(const Program * program) = 0;
};

class Node {};

class CommandNode : Node {
    public:
        Command command;
        void accept (Visitor & v) {
            v.visit(this);
        }
};

class Loop : Node {
    public:
        vector<Node*> children;
        void accept (Visitor & v) {
            v.visit(this);
        }
};

class Program : Node {
    public:
        vector<Node*> children;
        void accept (Visitor & v) {
            v.visit(this);
        }
};

/**
 * Read in the file by recursive descent.
 * Modify program as necessary
 */
void parse(fstream & file, Program * program) {
    char c;
    // How to peek at the next character
    c = (char)file.peek();
    // How to print out that character
    cout << c;
    // How to read a character from the file and advance to the next character
    file >> c;
    // How to print out that character
    cout << c;
    // How to insert a node into the program. NOTE: you want to push only Loop or CommandNode, not Node
    program->children.push_back(new Node());
}

int main(int argc, char *argv[]) {
    fstream file;
    Program program;
    if (argc == 1) {
        cout << argv[0] << ": No input files." << endl;
    } else if (argc > 1) {
        for (int i = 1; i < argc; i++) {
            file.open(argv[i], fstream::in);
            parse(file, & program);
            file.close();
        }
    }
}