#ifndef CPP_MAP_GENERATOR_H
#define CPP_MAP_GENERATOR_H

#include <godot_cpp/classes/sprite2d.hpp>

namespace godot {

class CppMapGenerator : public Node {
  GDCLASS(CppMapGenerator, Node)

private:
  // Add your variables here.

protected:
  static void _bind_methods();

public:
  CppMapGenerator();
  ~CppMapGenerator();

  TypedArray<int32_t> smooth(
    TypedArray<int32_t> input,
    int32_t width,
    int32_t height,
    int32_t steps,
    int32_t death_limit,
    int32_t birth_limit
  );
};

}

#endif