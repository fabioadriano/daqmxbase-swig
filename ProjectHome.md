The National Instruments NI-DAQmx Base C API for data acquisition supports most National Instruments data acquisition hardware. This SWIG wrapper gives you access to the library from scripting languages.

The NI-DAQmx Base library is available for Windows, Mac OS X, and Linux, as well as certain PDAs. The initial focus of this project is support for the NI USB-6008/6009 devices using the Ruby programming language. So some of the API that doesn't apply to the USB-6009 isn't wrapped yet, and the support is Ruby-specific in places.

I'd love to extend the support to other languages, but this is my first SWIG project and I don't know all the ins and outs of the language yet.