module Font exposing (Font, map, scale, getCharacter, typesetLine)

import Dict exposing (Dict)


type alias Font a =
    { width : Float
    , height : Float
    , replacement : a
    , characters : Dict Char a
    }


map : (a -> b) -> Font a -> Font b
map f font =
    { font
        | replacement = f font.replacement
        , characters = font.characters |> Dict.map (always f)
    }


scale : (Float -> a -> a) -> Float -> Font a -> Font a
scale f s font =
    { font
        | width = font.width * s
        , height = font.height * s
    }
        |> map (f s)


getCharacter : Char -> Font a -> a
getCharacter char font =
    font.characters
        |> Dict.get char
        |> Maybe.withDefault font.replacement


typesetLine : (Float -> a -> b) -> Font a -> Float -> String -> List b
typesetLine typesetCharacter font initialOffset string =
    string
        |> String.toList
        |> List.foldl
            (\char ( offset, list ) ->
                ( offset + font.width
                , if char == ' ' then
                    list
                  else
                    font
                        |> getCharacter char
                        |> typesetCharacter offset
                        |> (flip (::)) list
                )
            )
            ( initialOffset, [] )
        |> Tuple.second
        |> List.reverse
