
extension IterableExtension<E> on Iterable<E> {
  int get hashIterable {
    return Object.hashAll(this);
  }
}
