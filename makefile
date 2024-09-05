# Define the compiler and assembler
CXX = g++
NASM = nasm

# Define compiler and assembler flags
CXXFLAGS = -std=c++11 -Wall -g
NASMFLAGS = -f elf64 #-fPIE   # Add -fPIE flag for Position Independent Executable

# Define the output executable name
OUTPUT = marker_detector

# Define the source files
CPP_SRC = main.cpp
ASM_SRC = find_marker.asm

# Define the object files
OBJ = main.o find_marker.o

# Rule to build the final executable
$(OUTPUT): $(OBJ)
	$(CXX) -m64 -o $(OUTPUT) $(OBJ) -no-pie   # Add -no-pie to disable PIE for the final executable

# Rule to compile the C++ source file
main.o: main.cpp
	$(CXX) $(CXXFLAGS) -m64 -c main.cpp

# Rule to assemble the assembly source file
find_marker.o: find_marker.asm
	$(NASM) $(NASMFLAGS) -o find_marker.o find_marker.asm

# Rule to clean the build directory
clean:
	rm -f $(OBJ) $(OUTPUT)
