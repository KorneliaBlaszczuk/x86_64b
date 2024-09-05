#include <iostream>
#include <fstream>

extern "C" int find_marker(unsigned char *bitmap, unsigned int *x_pos, unsigned int *y_pos);

int main(int argc, char *argv[]) {
    if (argc < 2) {
        std::cout << "Please specify input filepath" << std::endl;
        return 0;
    }

    std::streampos size;
    char *memblock;

    std::ifstream file(argv[1], std::ios::in | std::ios::binary | std::ios::ate);
    if (file.is_open()) {
        size = file.tellg();
        memblock = new char[size];
        file.seekg(0, std::ios::beg);
        file.read(memblock, size);
        file.close();
        std::cout << "File loaded into memory, extracting BMP dimensions..." << std::endl;

        std::cout << "Executing nasm function..." << std::endl;

        // Allocate memory for x and y positions
        unsigned int x_pos[50] = {0}; // Assuming max 100 markers
        unsigned int y_pos[50] = {0}; // Assuming max 100 markers

        int result = find_marker(reinterpret_cast<unsigned char*>(memblock), x_pos, y_pos);
        if (result < 0) { result = -1;}
        std::cout << "Result code: " << result << std::endl;

        if(result > 0) {
            for(int i = 0; i < result; i++) {
                std::cout << "Marker " << i+1 << " Position - X: " << x_pos[i] << ", Y: " << y_pos[i] << std::endl;
            }
        }

        std::cout << "Finished." << std::endl;

        delete[] memblock;
    } else {
        std::cout << "Unable to open specified file!" << std::endl;
    }
    return 0;
}
