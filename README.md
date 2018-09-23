# Geolocation in Elm

Your client code is running on someone's device somewhere in the world. This library helps you find out *where* that device happens to be. If you are lucky, it may even tell you how fast the device is moving!

It is based on the [JavaScript Geolocation API][geo]. You can read about how to use libraries with tasks and subscriptions in [guide.elm-lang.org](http://guide.elm-lang.org/), particularly the section on [The Elm Architecture](http://guide.elm-lang.org/architecture/index.html).

[geo]: https://developer.mozilla.org/en-US/docs/Web/API/Geolocation

This is a conversion of the Elm 0.18 [elm-lang/geolocation](https://package.elm-lang.org/packages/elm-lang/geolocation/latest) package. That package used native code and an `effect module`, which user code is not allowed to do, so I converted it to use ports, shared with other clients of [billstclair/elm-port-funnel](https://package.elm-lang.org/packages/billstclair/elm-port-funnel/latest).

See the README in the [example](https://github.com/billstclair/elm-geolocation/tree/master/example) directory for instructions on running the example. It's live at [billstclair.github.io/elm-geolocation](https://billstclair.github.io/elm-geolocation/).

Bill St. Clair, 22 September 2018
