# Buildroot.cmake

This is a CMake module that can be used to drive multiple
[Buildroot] builds from a CMake-generated build system.

It might be useful if...

* ... you have a build process that involves building multiple
      components, with different configurations, from the same
      Buildroot source tree.

* ... you want to use the output of one or more Buildroot builds as part
      of a larger CMake-generated buiid process.

* ... you want to cache the results of one or more Buildroot builds using
      [Artifactory.cmake], or some other binary artifact caching system that
      integrates with CMake.

For more information, see the inline documentation comments in
[Buildroot.cmake].

[Artifactory.cmake]: https://github.com/raumfeld/Artifactory.cmake
[Buildroot.cmake]: https://github.com/raumfeld/Buildroot.cmake/blob/master/Buildroot.cmake
[Buildroot]: https://github.com/raumfeld/Artifactory.cmake
