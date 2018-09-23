module PortFunnel.Geolocation exposing
    ( Location, Altitude, Movement(..)
    , watchChanges, stopWatching
    , now, Error(..)
    , nowWith, Options, defaultOptions
    , Message, State, Response(..)
    , moduleName, moduleDesc, commander
    , initialState
    , send
    , toString, toJsonString
    , makeSimulatedCmdPort
    , isLoaded, errorToString
    )

{-| Find out about where a user’s device is located. [Geolocation API][geo].

[geo]: https://developer.mozilla.org/en-US/docs/Web/API/Geolocation


# Location

@docs Location, Altitude, Movement


# Subscribe to Changes

@docs watchChanges, stopWatching


# Get Current Location

@docs now, Error


# Options

@docs nowWith, Options, defaultOptions


# The Standard PortFunnel interface


## Types

@docs Message, State, Response


## Components of a `PortFunnel.FunnelSpec`

@docs moduleName, moduleDesc, commander


## Initial `State`

@docs initialState


## Sending a `Message` out the `Cmd` Port

@docs send


## Conversion to Strings

@docs toString, toJsonString


## Simulator

@docs makeSimulatedCmdPort


## Non-standard Functions

@docs isLoaded, errorToString

-}

import Json.Decode as JD exposing (Decoder)
import Json.Encode as JE exposing (Value)
import PortFunnel exposing (GenericMessage, ModuleDesc)
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
    = Startup
    | GetLocation Options
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
watchChanges : Message
watchChanges =
    SendChanges


{-| Stop receiving changes as the browser device moves.
-}
stopWatching : Message
stopWatching =
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



---
--- The PortFunnel default interface
---


{-| Internal module state.
-}
type State
    = State
        { isLoaded : Bool
        }


{-| Returns true if a `Startup` message has been processed.

This is sent by the port code after it has initialized.

-}
isLoaded : State -> Bool
isLoaded (State state) =
    state.isLoaded


{-| Responses.

`LocationResponse` is returned from a `now` or `nowWith` message, and for changes if you've subscriped with a `changes` message.

`ErrorResponse` is returned if there is an error.

`NoResponse` is sent if the processing code receives a message that is not a valid response message. Shouldn't happen.

-}
type Response
    = LocationResponse Location
    | ErrorResponse Error
    | NoResponse


{-| The initial, empty state, so the application can initialize its state.
-}
initialState : State
initialState =
    State
        { isLoaded = False
        }


{-| The name of this module: "Geolocation".
-}
moduleName : String
moduleName =
    "Geolocation"


{-| Our module descriptor.
-}
moduleDesc : ModuleDesc Message State Response
moduleDesc =
    PortFunnel.makeModuleDesc moduleName encode decode process


optionsEncoder : Options -> Value
optionsEncoder options =
    JE.object
        [ ( "enableHighAccuracy", JE.bool options.enableHighAccuracy )
        , ( "timeout"
          , case options.timeout of
                Nothing ->
                    JE.null

                Just to ->
                    JE.int to
          )
        , ( "maximumAge"
          , case options.maximumAge of
                Nothing ->
                    JE.null

                Just age ->
                    JE.int age
          )
        ]


altitudeEncoder : Altitude -> Value
altitudeEncoder altitude =
    JE.object
        [ ( "value", JE.float altitude.value )
        , ( "accuracy", JE.float altitude.accuracy )
        ]


movementEncoder : Movement -> Value
movementEncoder movement =
    case movement of
        Static ->
            JE.string "static"

        Moving { speed, degreesFromNorth } ->
            JE.object
                [ ( "speed", JE.float speed )
                , ( "degreesFromNorth", JE.float degreesFromNorth )
                ]


locationEncoder : Location -> Value
locationEncoder location =
    JE.object
        [ ( "latitude", JE.float location.latitude )
        , ( "longitude", JE.float location.longitude )
        , ( "accuracy", JE.float location.accuracy )
        , ( "altitude"
          , case location.altitude of
                Nothing ->
                    JE.null

                Just alt ->
                    altitudeEncoder alt
          )
        , ( "movement"
          , case location.movement of
                Nothing ->
                    JE.null

                Just move ->
                    movementEncoder move
          )
        , ( "timestamp", JE.int <| Time.posixToMillis location.timestamp )
        ]


errorEncoder : Error -> Value
errorEncoder error =
    case error of
        PermissionDenied string ->
            JE.object [ ( "PermissionDenied", JE.string string ) ]

        LocationUnavailable string ->
            JE.object [ ( "LocationUnavailable", JE.string string ) ]

        Timeout string ->
            JE.object [ ( "Timeout", JE.string string ) ]


encode : Message -> GenericMessage
encode message =
    case message of
        GetLocation options ->
            GenericMessage moduleName "getlocation" <| optionsEncoder options

        SendChanges ->
            GenericMessage moduleName "sendchanges" JE.null

        StopChanges ->
            GenericMessage moduleName "stopchanges" JE.null

        ReturnedLocation location ->
            GenericMessage moduleName "location" <| locationEncoder location

        ReturnedError error ->
            GenericMessage moduleName "error" <| errorEncoder error

        Startup ->
            GenericMessage moduleName "startup" JE.null


getLocationDecoder : Decoder Message
getLocationDecoder =
    JD.map GetLocation optionsDecoder


optionsDecoder : Decoder Options
optionsDecoder =
    JD.map3 Options
        (JD.field "enableHighAccuracy" JD.bool)
        (JD.field "timeout" <| JD.nullable JD.int)
        (JD.field "maximumAge" <| JD.nullable JD.int)


altitudeDecoder : Decoder Altitude
altitudeDecoder =
    JD.map2 Altitude
        (JD.field "value" JD.float)
        (JD.field "accuracy" JD.float)


movementDecoder : Decoder Movement
movementDecoder =
    JD.oneOf
        [ JD.string
            |> JD.andThen
                (\s ->
                    if s == "static" then
                        JD.succeed Static

                    else
                        JD.fail "String not \"static\""
                )
        , JD.map2
            (\speed degreesFromNorth ->
                Moving
                    { speed = speed
                    , degreesFromNorth = degreesFromNorth
                    }
            )
            (JD.field "speed" JD.float)
            (JD.field "degreesFromNorth" JD.float)
        ]


returnedLocationDecoder : Decoder Message
returnedLocationDecoder =
    JD.map ReturnedLocation locationDecoder


locationDecoder : Decoder Location
locationDecoder =
    JD.map6 Location
        (JD.field "latitude" JD.float)
        (JD.field "longitude" JD.float)
        (JD.field "accuracy" JD.float)
        (JD.field "altitude" <| JD.nullable altitudeDecoder)
        (JD.field "movement" <| JD.nullable movementDecoder)
        (JD.map Time.millisToPosix (JD.field "timestamp" JD.int))


returnedErrorDecoder : Decoder Message
returnedErrorDecoder =
    JD.map ReturnedError errorDecoder


errorDecoder : Decoder Error
errorDecoder =
    JD.oneOf
        [ JD.map PermissionDenied
            (JD.field "PermissionDenied" JD.string)
        , JD.map LocationUnavailable
            (JD.field "LocationUnavailable" JD.string)
        , JD.map Timeout
            (JD.field "Timeout" JD.string)
        ]


decodeValue : Decoder a -> Value -> Result String a
decodeValue decoder value =
    case JD.decodeValue decoder value of
        Err error ->
            Err <| JD.errorToString error

        Ok a ->
            Ok a


decode : GenericMessage -> Result String Message
decode { tag, args } =
    case tag of
        "getlocation" ->
            decodeValue getLocationDecoder args

        "sendchanges" ->
            Ok SendChanges

        "stopchanges" ->
            Ok StopChanges

        "location" ->
            decodeValue returnedLocationDecoder args

        "error" ->
            decodeValue returnedErrorDecoder args

        "startup" ->
            Ok Startup

        _ ->
            Err <| "Unknown Echo tag: " ++ tag


{-| Send a `Message` through a `Cmd` port.
-}
send : (Value -> Cmd msg) -> Message -> Cmd msg
send =
    PortFunnel.sendMessage moduleDesc


process : Message -> State -> ( State, Response )
process message ((State state) as unboxed) =
    case message of
        Startup ->
            ( State { state | isLoaded = True }
            , NoResponse
            )

        ReturnedLocation location ->
            ( unboxed, LocationResponse location )

        ReturnedError location ->
            ( unboxed, ErrorResponse location )

        _ ->
            ( unboxed, NoResponse )


{-| Responsible for sending a `CmdResponse` back througt the port.

Called by `PortFunnel.appProcess` for each response returned by `process`.

Always returns `Cmd.none`.

-}
commander : (GenericMessage -> Cmd msg) -> Response -> Cmd msg
commander _ _ =
    Cmd.none


defaultLocation : Location
defaultLocation =
    -- NoRedInk in San Francisco
    { latitude = 37.7875982
    , longitude = -122.4018747
    , accuracy = 471
    , altitude = Nothing
    , movement = Nothing
    , timestamp = Time.millisToPosix 1537666531262
    }


simulator : Message -> Maybe Message
simulator message =
    case message of
        GetLocation _ ->
            Just <| ReturnedLocation defaultLocation

        SendChanges ->
            simulator <| GetLocation defaultOptions

        _ ->
            Nothing


{-| Make a simulated `Cmd` port.
-}
makeSimulatedCmdPort : (Value -> msg) -> Value -> Cmd msg
makeSimulatedCmdPort =
    PortFunnel.makeSimulatedFunnelCmdPort
        moduleDesc
        simulator


{-| Convert a `Message` to a nice-looking human-readable string.
-}
toString : Message -> String
toString message =
    case message of
        Startup ->
            "Startup"

        GetLocation options ->
            "GetLocation " ++ optionsToString options

        SendChanges ->
            "SendChanges"

        StopChanges ->
            "StopChanges"

        ReturnedLocation location ->
            "ReturnedLocation " ++ locationToString location

        ReturnedError error ->
            "ReturnedError (" ++ errorToString error ++ ")"


optionsToString : Options -> String
optionsToString options =
    let
        { enableHighAccuracy, timeout, maximumAge } =
            options
    in
    "{ enableHighAccuracy: "
        ++ (if enableHighAccuracy then
                "True"

            else
                "False"
           )
        ++ ", timeout: "
        ++ (case timeout of
                Nothing ->
                    "Nothing"

                Just time ->
                    String.fromInt time
           )
        ++ ", maximumAge: "
        ++ (case maximumAge of
                Nothing ->
                    "Nothing"

                Just age ->
                    String.fromInt age
           )
        ++ " }"


locationToString : Location -> String
locationToString location =
    let
        { latitude, longitude } =
            location
    in
    "{ latitude: "
        ++ String.fromFloat latitude
        ++ ", longitude: "
        ++ String.fromFloat longitude
        ++ " }"


errorToString : Error -> String
errorToString error =
    case error of
        PermissionDenied string ->
            "PermissionDenied \"" ++ string ++ "\""

        LocationUnavailable string ->
            "LocationUnavailable \"" ++ string ++ "\""

        Timeout string ->
            "Timeout \"" ++ string ++ "\""


{-| Convert a `Message` to the same JSON string that gets sent

over the wire to the JS code.

-}
toJsonString : Message -> String
toJsonString message =
    message
        |> encode
        |> PortFunnel.encodeGenericMessage
        |> JE.encode 0
