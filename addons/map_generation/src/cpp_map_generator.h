#ifndef CPP_MAP_GENERATOR_H
#define CPP_MAP_GENERATOR_H

#include <godot_cpp/classes/sprite2d.hpp>

namespace godot {

class CppMapGenerator : public Node {
  GDCLASS(CppMapGenerator, Object)

private:
  // Add your variables here.

protected:
  static void _bind_methods();

public:
  static TypedArray<int32_t> smooth(
    TypedArray<int32_t> input_map,
    int32_t width,
    int32_t height,
    int32_t steps,
    int32_t death_limit,
    int32_t birth_limit
  );

  static int32_t count_neighbors(
    TypedArray<int32_t> input_map,
    int32_t width,
    int32_t height,
    int32_t x,
    int32_t y,
    int32_t radius = 1
  );

  CppMapGenerator();
  ~CppMapGenerator();
};

}

#endif