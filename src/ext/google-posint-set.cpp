#include <cstdint>
#include <sparsehash/dense_hash_set>

using google::dense_hash_set;

extern "C" {
  void* posint_set_new() {
    auto set = new dense_hash_set<int32_t>;
    set->set_empty_key(-1);
    set->set_deleted_key(-2);
    return static_cast<void*>(set);
  }

  void posint_set_finalize(void* self) {
    delete static_cast<dense_hash_set<int32_t>*>(self);
  }

  void posint_set_clear(void* self) {
    static_cast<dense_hash_set<int32_t>*>(self)->clear();
  }

  void posint_set_push(void* self, int32_t x) {
    static_cast<dense_hash_set<int32_t>*>(self)->insert(x);
  }

  bool posint_set_includes(void* self, int32_t x) {
    return static_cast<dense_hash_set<int32_t>*>(self)->find(x) != static_cast<dense_hash_set<int32_t>*>(self)->end();
  }

  void posint_set_delete(void* self, int32_t x) {
    auto set = static_cast<dense_hash_set<int32_t>*>(self);
    set->erase(x);
  }

  void posint_set_iterate(void* self, void* (iteratee)(int32_t, void*), void* data) {
    auto set = static_cast<dense_hash_set<int32_t>*>(self);
    for (int32_t item : *set)
      iteratee(item, data);
  }

  size_t posint_set_size(void* self) {
    return static_cast<dense_hash_set<int32_t>*>(self)->size();
  }

  bool posint_set_eq(void* self, void* other) {
    return *static_cast<dense_hash_set<int32_t>*>(self) == *static_cast<dense_hash_set<int32_t>*>(other);
  }
}
