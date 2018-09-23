----------------------------------------------------------------------
--
-- Main.elm
-- Geolocation example
-- Copyright (c) 2018 Bill St. Clair <billstclair@gmail.com>
-- Some rights reserved.
-- Distributed under the BSD-3-Clause License
-- See LICENSE
--
----------------------------------------------------------------------


port module Main exposing (main)

import Browser
import Cmd.Extra exposing (addCmd, addCmds, withCmd, withCmds, withNoCmd)
import Dict exposing (Dict)
import Html exposing (Html, a, button, div, h2, input, p, span, table, td, text, tr)
import Html.Attributes exposing (href, style, type_, value)
import Html.Events exposing (onClick, onInput)
import Json.Decode as JD
import Json.Encode as JE exposing (Value)
import PortFunnel exposing (FunnelSpec, GenericMessage, ModuleDesc, StateAccessors)
import PortFunnel.Geolocation as Geolocation
    exposing
        ( Message
        , Movement(..)
        , Response(..)
        )
import Time


port cmdPort : Value -> Cmd msg


port subPort : (Value -> msg) -> Sub msg


subscriptions : Model -> Sub Msg
subscriptions model =
    subPort Process


simulatedCmdPort : Value -> Cmd Msg
simulatedCmdPort =
    Geolocation.makeSimulatedCmdPort Process


getCmdPort : Model -> (Value -> Cmd Msg)
getCmdPort model =
    if model.useSimulator then
        simulatedCmdPort

    else
        cmdPort


type alias FunnelState =
    { geolocation : Geolocation.State }


type alias Model =
    { location : Maybe Geolocation.Location
    , count : Int
    , watching : Bool
    , useSimulator : Bool
    , wasLoaded : Bool
    , state : FunnelState
    , error : Maybe String
    }


type Msg
    = GetLocation
    | ToggleWatch
    | Process Value


main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }


init : () -> ( Model, Cmd Msg )
init () =
    { location = Nothing
    , count = 0
    , watching = False
    , useSimulator = True
    , wasLoaded = False
    , state = { geolocation = Geolocation.initialState }
    , error = Nothing
    }
        |> withNoCmd


geolocationAccessors : StateAccessors FunnelState Geolocation.State
geolocationAccessors =
    StateAccessors .geolocation (\substate state -> { state | geolocation = substate })


type alias AppFunnel substate message response =
    FunnelSpec FunnelState substate message response Model Msg


type Funnel
    = GeolocationFunnel (AppFunnel Geolocation.State Geolocation.Message Geolocation.Response)


funnels : Dict String Funnel
funnels =
    Dict.fromList
        [ ( Geolocation.moduleName
          , GeolocationFunnel <|
                FunnelSpec geolocationAccessors
                    Geolocation.moduleDesc
                    Geolocation.commander
                    geolocationHandler
          )
        ]


doIsLoaded : Model -> Model
doIsLoaded model =
    if not model.wasLoaded && Geolocation.isLoaded model.state.geolocation then
        { model
            | useSimulator = False
            , wasLoaded = True
        }

    else
        model


geolocationHandler : Geolocation.Response -> FunnelState -> Model -> ( Model, Cmd Msg )
geolocationHandler response state mdl =
    let
        model =
            doIsLoaded
                { mdl | state = state }
    in
    case response of
        LocationResponse location ->
            { model
                | location = Just location
                , count = model.count + 1
            }
                |> withNoCmd

        ErrorResponse error ->
            { model
                | error = Just <| Geolocation.errorToString error
            }
                |> withNoCmd

        _ ->
            model |> withNoCmd


update : Msg -> Model -> ( Model, Cmd Msg )
update msg modl =
    let
        model =
            { modl | error = Nothing }
    in
    case msg of
        GetLocation ->
            model
                |> withCmd
                    (send Geolocation.now model)

        ToggleWatch ->
            { model | watching = not model.watching }
                |> withCmd
                    (send
                        (if model.watching then
                            Geolocation.stopWatching

                         else
                            Geolocation.watchChanges
                        )
                        model
                    )

        Process value ->
            case
                PortFunnel.processValue funnels
                    appTrampoline
                    value
                    model.state
                    model
            of
                Err error ->
                    { model | error = Just error } |> withNoCmd

                Ok res ->
                    res


appTrampoline : GenericMessage -> Funnel -> FunnelState -> Model -> Result String ( Model, Cmd Msg )
appTrampoline genericMessage funnel state model =
    let
        theCmdPort =
            getCmdPort model
    in
    case funnel of
        GeolocationFunnel geolocationFunnel ->
            PortFunnel.appProcess theCmdPort
                genericMessage
                geolocationFunnel
                state
                model


send : Message -> Model -> Cmd Msg
send message model =
    Geolocation.send (getCmdPort model) message


decodeString : Value -> String
decodeString value =
    case JD.decodeValue JD.string value of
        Ok res ->
            res

        Err err ->
            JD.errorToString err


br : Html msg
br =
    Html.br [] []


b : String -> Html msg
b string =
    Html.b [] [ text string ]


ps : List (Html msg) -> Html msg
ps paragraphs =
    List.map (\para -> p [] [ para ]) paragraphs
        |> div []


fontSize =
    style "font-size" "24px"


buttonFontSize =
    style "font-size" "36px"


view : Model -> Html Msg
view model =
    div [ fontSize ]
        [ h2 [] [ text "Geolocation Example" ]
        , case model.error of
            Nothing ->
                text ""

            Just err ->
                p [ style "color" "red" ]
                    [ text err ]
        , p []
            [ button
                [ onClick GetLocation
                , buttonFontSize
                ]
                [ text "Get" ]
            , text " "
            , button
                [ onClick ToggleWatch
                , buttonFontSize
                ]
                [ text <|
                    if model.watching then
                        "Unwatch"

                    else
                        "Watch"
                ]
            ]
        , p []
            [ b "Simulator: "
            , text <|
                if model.useSimulator then
                    "yes"

                else
                    "no"
            ]
        , case model.location of
            Nothing ->
                text ""

            Just location ->
                p []
                    [ b "Count: "
                    , text <| String.fromInt model.count
                    , br
                    , b "Latitude: "
                    , text <| String.fromFloat location.latitude
                    , br
                    , b "Longitude: "
                    , text <| String.fromFloat location.longitude
                    , br
                    , b "Accuracy: "
                    , text <| String.fromFloat location.accuracy
                    , case location.altitude of
                        Nothing ->
                            text ""

                        Just altitude ->
                            span []
                                [ br
                                , b "Altitude: "
                                , text <| String.fromFloat altitude.value
                                , text ", accuracy: "
                                , text <| String.fromFloat altitude.accuracy
                                ]
                    , case location.movement of
                        Nothing ->
                            text ""

                        Just movement ->
                            span []
                                [ br
                                , b "Movement: "
                                , case movement of
                                    Static ->
                                        text "static"

                                    Moving { speed, degreesFromNorth } ->
                                        span []
                                            [ text "speed: "
                                            , text <| String.fromFloat speed
                                            , text " heading: "
                                            , text <| String.fromFloat degreesFromNorth
                                            ]
                                ]
                    , br
                    , b "Timestamp: "
                    , text <| String.fromInt (Time.posixToMillis location.timestamp)
                    ]
        , ps
            [ span []
                [ text "This is an example of the "
                , a [ href "http://package.elm-lang.org/packages/billstclair/elm-geolocation/latest" ]
                    [ text "billstclair/elm-geolocation" ]
                , text " Elm package."
                ]
            , span []
                [ text "Press the 'Get' button to get the location now."
                , br
                , text "Press the 'Watch' button to report changes in location."
                , br
                , text "Press the 'Unwatch' button to stop reporting changes."
                ]
            , a [ href "https://github.com/billstclair/elm-geolocation" ]
                [ text "Source at GitHub" ]
            ]
        ]
