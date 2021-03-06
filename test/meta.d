module beard.test.meta;

import beard.meta.find;
import beard.meta.contains;
import beard.io;

import std.typetuple : staticMap;

template isFloat(T) {
   enum isFloat = is(T == float);
}

template isFloatOrBool(T) {
   enum isFloatOrBool = is(T == float) || is(T == bool);
}

template floatOrBoolToVoid(T) {
   static if(isFloatOrBool!T)
       alias void floatOrBoolToVoid;
   else
       alias T floatOrBoolToVoid;
}

int main() {
    println(typeid(find!(isFloat, bool, bool, bool, float)));
    println(typeid(find!(isFloat, bool, bool, int, int)));
    println(containsMatch!(isFloat, bool, bool, bool, float));
    println(containsMatch!(isFloat, bool, bool, int, int));

    println(typeid(findAll!(isFloatOrBool, int, bool, double, float, float, int)));
    println(typeid(filter!(isFloatOrBool, int, bool, double, float, float, int)));

    println(typeid(
        staticMap!(floatOrBoolToVoid, float, bool, double, bool, int, bool, float)));
    return 0;
}
// vim:ts=4 sw=4
