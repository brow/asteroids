module Main exposing (main)

import AnimationFrame
import Html exposing (Html)
import Html.Attributes
import Json.Decode exposing (Decoder)
import Random.Pcg as Random exposing (Generator)
import Svg exposing (Svg)
import Svg.Attributes
import Svg.Events
import Time exposing (Time)


-- project

import Geometry.Polygon as Polygon exposing (Polygon)
import Geometry.Vector as Vector exposing (Vector, Point)
import Util exposing (transformPoints, wrapPosition)
import Particle exposing (Particle)
import Screen
import Types exposing (Moving, Expiring, Positioned)


type alias Model =
    { drag : Maybe ( Point, Point )
    , seed : Random.Seed
    , particles : List Particle
    , polygon : Polygon
    }


main : Program Never Model Msg
main =
    Html.program
        { init =
            ( { drag = Nothing
              , seed = Random.initialSeed 3780540833
              , particles = []
              , polygon = Polygon.ngon 5 |> List.map (Vector.scale 10)
              }
            , Cmd.none
            )
        , update = \x r -> ( update x r, Cmd.none )
        , view = view
        , subscriptions = always (AnimationFrame.diffs (Time.inSeconds >> Tick))
        }



-- update


type Msg
    = MouseDown Point
    | MouseMove Point
    | MouseUp
    | Tick Time


update : Msg -> Model -> Model
update msg model =
    case msg of
        MouseDown p0 ->
            { model | drag = Just ( p0, p0 ) }

        MouseMove p1 ->
            case model.drag of
                Just ( p0, _ ) ->
                    { model | drag = Just ( p0, p1 ) }

                Nothing ->
                    model

        MouseUp ->
            case model.drag of
                Just ( p0, p1 ) ->
                    let
                        ( particles, seedNext ) =
                            Random.map
                                (\( burst, polygonParts ) ->
                                    burst
                                        ++ polygonParts
                                        |> List.map (adjustParticle p1 (Vector.sub p1 p0))
                                )
                                (Random.pair
                                    (Particle.burst 300 100 10)
                                    (Particle.explode 100 150 model.polygon)
                                )
                                |> (flip Random.step) model.seed
                    in
                        { model
                            | drag = Nothing
                            , seed = seedNext
                            , particles = model.particles ++ particles
                        }

                Nothing ->
                    model

        Tick dt ->
            { model | particles = model.particles |> List.filterMap (updateParticle dt) }


adjustParticle : Point -> Vector -> Particle -> Particle
adjustParticle position velocity particle =
    { particle
        | position = particle.position |> Vector.add position
        , velocity = particle.velocity |> Vector.add velocity
    }


updateParticle : Time -> Particle -> Maybe Particle
updateParticle dt =
    updateMoving dt >> wrapPosition screenSize >> updateExpiring dt


updateMoving : Time -> Moving (Positioned a) -> Moving (Positioned a)
updateMoving dt obj =
    { obj
        | position = obj.position |> Vector.add (obj.velocity |> Vector.scale dt)
        , rotation = obj.rotation + obj.angularVelocity * dt
    }


updateExpiring : Time -> Expiring a -> Maybe (Expiring a)
updateExpiring dt obj =
    if obj.timeRemaining > 0 then
        Just
            { obj | timeRemaining = obj.timeRemaining - dt }
    else
        Nothing



-- view


screenSize : ( Float, Float )
screenSize =
    ( 1200, 900 )


( width, height ) =
    screenSize


view : Model -> Html Msg
view { drag, particles, polygon } =
    let
        attributes =
            [ Svg.Attributes.width (width |> px)
            , Svg.Attributes.height (height |> px)
            , Svg.Attributes.style "cursor: default;"
            ]

        events =
            drag
                |> Maybe.map
                    (always [ mousemove, mouseup ])
                |> Maybe.withDefault [ mousedown ]

        paths : List Screen.Path
        paths =
            List.concat
                [ drag |> Maybe.map (\( _, p1 ) -> polygon |> List.map (Vector.add p1) |> (,,) 1 True) |> listFromMaybe
                , particles |> List.map particleToPath
                ]
    in
        Html.div
            [ Html.Attributes.style
                [ ( "height", "100vh" )
                , ( "fill", "none" )
                , ( "stroke", "gray" )
                , ( "stroke-width", "2px" )
                ]
            ]
            [ Svg.svg
                (attributes ++ events)
                [ drag |> Maybe.map viewLine |> Maybe.withDefault (Svg.g [] [])
                , paths |> Screen.render screenSize
                ]
            ]


particleToPath : Particle -> Screen.Path
particleToPath { polyline, position, rotation } =
    ( 1, False, polyline |> transformPoints position rotation )


viewLine : ( Point, Point ) -> Svg a
viewLine ( ( x1, y1 ), ( x2, y2 ) ) =
    Svg.line
        [ Svg.Attributes.x1 (x1 |> px)
        , Svg.Attributes.y1 (y1 |> px)
        , Svg.Attributes.x2 (x2 |> px)
        , Svg.Attributes.y2 (y2 |> px)
        , Svg.Attributes.style "stroke: rgba(0, 0, 0, 0.1)"
        ]
        []


px : Float -> String
px =
    toString >> (++) >> (|>) "px"



-- events


mouseup : Svg.Attribute Msg
mouseup =
    Svg.Events.on "mouseup" (Json.Decode.succeed MouseUp)


mousedown : Svg.Attribute Msg
mousedown =
    Svg.Events.on "mousedown" (decodeMouseOffset |> Json.Decode.map MouseDown)


mousemove : Svg.Attribute Msg
mousemove =
    Svg.Events.on "mousemove" (decodeMouseOffset |> Json.Decode.map MouseMove)


decodeMouseOffset : Decoder Point
decodeMouseOffset =
    Json.Decode.map2
        (,)
        (Json.Decode.field "offsetX" Json.Decode.float)
        (Json.Decode.field "offsetY" Json.Decode.float)



-- list


listFromMaybe : Maybe a -> List a
listFromMaybe mx =
    case mx of
        Just x ->
            [ x ]

        Nothing ->
            []
