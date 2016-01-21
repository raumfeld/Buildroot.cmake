# Buildroot.cmake

This is a [CMake] module that can be used to drive multiple
[Buildroot] builds from a CMake-generated build system.

It might be useful if...

* ... you have a build process that involves building multiple
      images, with different configurations, from the same
      Buildroot source tree.

* ... you want to use the output of one or more Buildroot builds as part
      of a larger CMake-generated build process.

* ... you want to cache the results of one or more Buildroot builds using
      [Artifactory.cmake], or some other binary artifact caching system that
      integrates with CMake.

For more information, see:

* the inline documentation comments in [Buildroot.cmake].

* the [examples](https://github.com/raumfeld/Buildroot.cmake/tree/master/examples/)

[Artifactory.cmake]: https://github.com/raumfeld/Artifactory.cmake
[Buildroot.cmake]: https://github.com/raumfeld/Buildroot.cmake/blob/master/Buildroot.cmake
[Buildroot]: https://github.com/raumfeld/Artifactory.cmake
[CMake]: https://www.cmake.org/
