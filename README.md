# hy340

The group project for class hy-340 in UOC Computer Science Department

The project's goal is the creating of a compiler for our custom language called "Alpha" and it consists of 5 phases :


Phase 1 :

    The goal is to create of our lexical analyzer (using flex).

Phase 2 :

    The goal is to create a syntactic analyzer for the "Alpha" language (using YACC) which operates on the output of phase 1.

Phase 3 :

    The goal is to build upon phase 2 and add semantic rules for syntax-driven intermediate code translation.
    The end product will be a .txt file which contains intermediate code in the form of "quads".

Phase 4-5 :

    The goal is to generate binary code and execute it using a pseudo virtual machine.
    
    Phase 5 : The goal is the creation of a virtual machine that will run our generated bytecode, in a nutshell its a loop that iterates
    through our bytecode and executes the instructions in it.
