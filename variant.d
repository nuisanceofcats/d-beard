module beard.variant;

import beard.meta.fold_left : foldLeft2;
import beard.meta.contains : contains;
import beard.io;
import std.c.string : memcpy;
import std.typetuple : staticIndexOf;
import std.traits : Unqual;

private template maxSize(size_t _size) {
    enum size = _size;
    template add(U) {
        alias maxSize!(_size > U.sizeof ? _size : U.sizeof) add;
    }
}

class BadVariantCopy : Throwable {
    this(string error) { super(error); }
}

// may store any of T or be empty.
// I would prefer only allowing empty if void is in T and creating an object
// of the first type when default initialising.
// Unfortunately D does not allow default constructors for structs :(
struct Variant(T...) {
    alias T          types;
    enum size =      foldLeft2!(maxSize!0u, T).size;
    enum n_types =   T.length;

    void opAssign(U)(auto ref U rhs) {
        static if (contains!(U, T)) {
            // copying object references like this is okay
            static if (is(T == class) && is(T == shared))
                memcpy(&value_, cast(const(void*)) &rhs, rhs.sizeof);
            else
                memcpy(&value_, &rhs, rhs.sizeof);
            idx_ = staticIndexOf!(U, T);
        }
        else static if (is(U == Variant)) {
            this.value_ = rhs.value_;
            this.idx_ = rhs.idx_;
        }
        else static if (isVariant!U) {
            struct copyVariant {
                void opCall(T)(T t) {
                    static if (contains!(T, types))
                        *dest = t;
                    else throw new BadVariantCopy(
                        "cannot store type source variant holds");
                }

                void empty() { dest.reset(); }

                this(Variant *v) { dest = v; }
                Variant *dest;
            }

            rhs.apply(copyVariant(&this));
        }
        else static assert(false, "invalid variant type");
    }

    void printTo(S)(int indent, S stream) {
        struct variantPrint {
            void opCall(T)(T t) { printIndented(stream_, indent_, t); }
            void empty() { printIndented(stream_, indent_, "<empty>"); }

            this(S s, int indent) { stream_ = s; indent_ = indent; }
            S stream_;
            int indent_;
        }

        apply(variantPrint(stream, indent));
    }

    // helper for creating forwarding array mixins
    private static string makeFwd(uint idx)() {
        static if (idx < T.length + 1)
            return (idx ? "," : "[") ~
                    "&fwd!" ~ idx.stringof ~ makeFwd!(idx + 1);
        else
            return "]";
    }

    private auto applyStruct(F)(ref F f) {
        alias typeof(f.opCall(T[0])) return_type;

        static return_type fwd(uint i)(ref Variant t, ref F f) {
            static if (i < T.length)
                return f.opCall(t.as!(T[i])());
            else
                return f.empty();
        }

        static return_type function(ref Variant, ref F)[T.length + 1] forwarders =
            mixin(makeFwd!0());

        return forwarders[this.idx_](this, f);
    }

    private static auto callMatching(A, F...)(auto ref A a, F f) {
        static if (! F.length) {
            static assert(false, "no matching function");
        }
        else static if (__traits(compiles, f[0](a))) {
            return f[0](a);
        }
        else {
            return callMatching(a, f[1..$]);
        }
    }

    private static auto callEmpty(F...)(F f) {
        static if (! F.length) {
            static assert(false, "no matching function for empty");
        }
        else static if (__traits(compiles, f[0]())) {
            return f[0]();
        }
        else {
            return callEmpty(f[1..$]);
        }
    }

    private auto applyFunctions(F...)(F f) {
        static if(is(F[0] return_type == return)) {
            static return_type fwd(uint i)(ref Variant t, F f) {
                static if (i < T.length) {
                    alias T[i] ArgType;
                    return callMatching(t.as!ArgType, f);
                }
                else
                    return callEmpty(f);
            }

            static return_type function(ref Variant, F)[T.length + 1] forwarders =
                mixin(makeFwd!0());

            return forwarders[this.idx_](this, f);
        }
        else {
            static assert(false, "incorrect arguments");
        }
    }

    // this calls directly through a compile time constructed vtable.
    auto apply(F...)(auto ref F f) {
        static if (F.length == 1 && __traits(hasMember, f[0], "opCall")) {
            return applyStruct(f[0]);
        }
        else {
            return applyFunctions(f);
        }
    }

    ref T as(T)() { return * cast(T*) &value_; }

    bool isType(U)() {
        static if (contains!(U, types))
            return idx_ == staticIndexOf!(U, types);
        else
            static assert(false, "type not in variant");
    }

    bool empty() @property const { return idx_ >= T.length; }

    void reset() {
        // run destructor on existing class?
        idx_ = n_types;
    }

    ////////////////////////////////////////////////////////////////////////
    this(U)(U rhs) { this = rhs; }

  private:
    union {
        ubyte[size] value_;
        // mark the region as a pointer to stop objects being garbage collected
        static if (size >= (void*).sizeof)
            void* p[size / (void*).sizeof];
    }

    uint idx_ = n_types;
}

template isVariant(T) {
    // d won't allow enum isVariant = is(...);
    static if (is(Unqual!T Unused : Variant!U, U...))
        enum isVariant = true;
    else
        enum isVariant = false;
}
