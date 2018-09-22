module PortFunnel.Geolocation exposing
    ( Location, Altitude, Movement(..)
    , changes, stopChanges
    , now, Error(..)
    , nowWith, Options, defaultOptions
    , Message
    )

{-| Find out about where a user’s device is located. [Geolocation API][geo].

[geo]: https://developer.mozilla.org/en-US/docs/Web/API/Geolocation


# Location

@docs Location, Altitude, Movement


# Subscribe to Changes

@docs changes, stopChanges


# Get Current Location

@docs now, Error


# Options

@docs nowWith, Options, defaultOptions

-}

import Time exposing (Posix)



-- LOCATION


{-| All available details of the device's current location in the world.

  - `latitude` &mdash; the latitude in decimal degrees.
  - `longitude` &mdash; the longitude in decimal degrees.
  - `accuracy` &mdash; the accuracy of the latitude and longitude, expressed in meters.
  - `altitude` &mdash; altitude information, if available.
  - `movement` &mdash; information about how the device is moving, if available.
  - `timestamp` &mdash; the time that this location reading was taken in milliseconds.

-}
type alias Location =
    { latitude : Float
    , longitude : Float
    , accuracy : Float
    , altitude : Maybe Altitude
    , movement : Maybe Movement
    , timestamp : Posix
    }


{-| The altitude in meters relative to sea level is held in `value`. The `accuracy` field
describes how accurate `value` is, also in meters.
-}
type alias Altitude =
    { value : Float
    , accuracy : Float
    }


{-| Describes the motion of the device. If the device is not moving, this will
just be `Static`. If the device is moving, you will see the `speed` in meters
per second and the `degreesFromNorth` in degrees.

**Note:** The `degreesFromNorth` value goes clockwise: 0° represents true
north, 90° is east, 180° is south, 270° is west, etc.

-}
type Movement
    = Static
    | Moving { speed : Float, degreesFromNorth : Float }



-- ERRORS


{-| The `now` functions may fail for a variety of reasons.

    * The user may reject the request to use their location.
    * It may be impossible to get a location.
    * If you set a timeout in the `Options` the request may just take too long.

In each case, the browser will provide a string with additional information.

-}
type Error
    = PermissionDenied String
    | LocationUnavailable String
    | Timeout String


{-| Messages sent between Elm and the port JavaScript.

Opaque type, returned by `now`, `nowWith`, `changes`, `stopChanges`.

-}
type Message
    = GetLocation Options
    | SendChanges
    | StopChanges
    | ReturnedLocation Location
    | ReturnedError Error


{-| Return a message to `send` to receive a location now.
-}
now : Message
now =
    nowWith defaultOptions


{-| Return a message to `send` to receive a location now with options.
-}
nowWith : Options -> Message
nowWith =
    GetLocation


{-| Enable receipt of changes as the browser device moves.
-}
changes : Message
changes =
    SendChanges


{-| Stop receiving changes as the browser device moves.
-}
stopChanges : Message
stopChanges =
    StopChanges



-- OPTIONS


{-| There are a couple options you can mess with when requesting location data.

  - `enableHighAccuracy` &mdash; When enabled, the device will attempt to provide
    a more accurate location. This can result in slower response times or
    increased power consumption (with a GPS chip on a mobile device for example).
    When disabled, the device can take the liberty to save resources by responding
    more quickly and/or using less power.
  - `timeout` &mdash; Requesting a location can take time, so you have the option
    to provide an upper bound in milliseconds on that wait.
  - `maximumAge` &mdash; This API can return cached locations. If this is set
    to `Just 400` you may get cached locations as long as they were read in the
    last 400 milliseconds. If this is `Nothing` then the device must attempt
    to retrieve the current location every time.

-}
type alias Options =
    { enableHighAccuracy : Bool
    , timeout : Maybe Int
    , maximumAge : Maybe Int
    }


{-| The options you will want in 99% of cases. This will get you faster
results, less battery drain, no surprise failures due to timeouts, and no
surprising cached results.

    { enableHighAccuracy = False
    , timeout = Nothing
    , maximumAge = Nothing
    }

-}
defaultOptions : Options
defaultOptions =
    { enableHighAccuracy = False
    , timeout = Nothing
    , maximumAge = Nothing
    }
