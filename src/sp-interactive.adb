-------------------------------------------------------------------------------
-- Copyright 2021, The Septum Developers (see AUTHORS file)

-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at

--     http://www.apache.org/licenses/LICENSE-2.0

-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-------------------------------------------------------------------------------
with Ada.Characters.Latin_1;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
-- with ANSI;
with SP.Commands;
with SP.Config;
-- with SP.File_System;
with SP.Searches; use SP.Searches;
with SP.Strings;  use SP.Strings;
with SP.Terminal;

with Trendy_Terminal;

package body SP.Interactive is
    use Ada.Strings.Unbounded;
    use SP.Terminal;

    procedure Write_Prompt (Srch : in Search) is
        -- Writes the prompt and get ready to read user input.
        Default_Prompt : constant String  := " > ";
        Extensions     : constant String_Vectors.Vector := List_Extensions (Srch);
        Context_Width  : constant Natural := SP.Searches.Get_Context_Width (Srch);
        Max_Results    : constant Natural := SP.Searches.Get_Max_Results (Srch);
        Second_Col     : constant := 30;
    begin
        New_Line;
        Put ("Files:     " & SP.Searches.Num_Files (Srch)'Image);
        Set_Col (Second_Col);
        Put ("Extensions: ");
        if Extensions.Is_Empty then
            Put ("Any");
        else
            Put ("(only) ");
            for Extension of Extensions loop
                Put (Extension);
                Put (" ");
            end loop;
        end if;
        New_Line;
        Put ("Distance:  " & (if Context_Width = SP.Searches.No_Context_Width then "Any" else Context_Width'Image));
        Set_Col (Second_Col);
        Put ("Max Results: " & (if Max_Results = SP.Searches.No_Max_Results then "Unlimited" else Max_Results'Image));
        New_Line;
        Put (Default_Prompt);
    end Write_Prompt;

    function Format_Input (S : String) return String is
    begin
        return S;
    end Format_Input;

    function Format_Array (S : SP.Strings.String_Vectors.Vector) return Unbounded_String is
        Result : Unbounded_String;
    begin
        Append (Result, To_Unbounded_String ("["));
        for Elem of S loop
            Append (Result, Ada.Characters.Latin_1.Quotation);
            Append (Result, Elem);
            Append (Result, Ada.Characters.Latin_1.Quotation);
            Append (Result, Ada.Characters.Latin_1.Comma);
            Append (Result, To_Unbounded_String (" "));
        end loop;
        Append (Result, To_Unbounded_String ("]"));
        return Result;
    end Format_Array;

    function Debug_Input (S : String) return String is
        Exploded : constant SP.Strings.Exploded_Line := SP.Strings.Make (S);
        Output   : Unbounded_String;
    begin
        Append (Output, Format_Array (Exploded.Words));
        Append (Output, Format_Array (Exploded.Spacers));
        Append (Output, SP.Strings.Zip (Exploded.Spacers, Exploded.Words));
        return To_String (Output);
    end Debug_Input;

    function Read_Command return String_Vectors.Vector is
    begin
        declare
            Input : constant Unbounded_String := To_Unbounded_String(
                Trendy_Terminal.Debug_Get_Line(
                    Format_Fn => Format_Input'Access,
                    Debug_Fn => Debug_Input'Access
                )
            );
            Exploded : constant SP.Strings.Exploded_Line := SP.Strings.Make (To_String (Input));
        begin
            -- This might want to be a more complicated algorithm for splitting, such as handling quotes
            return Exploded.Words;
        end;
    end Read_Command;

    procedure Main is
        -- The interactive loop through which the user starts a search context and then interatively refines it by
        -- pushing and popping operations.
        Command_Line : String_Vectors.Vector;
        Srch         : SP.Searches.Search;
        Configs      : constant String_Vectors.Vector := SP.Config.Config_Locations;
    begin
        Put_Line ("septum v" & SP.Version);
        New_Line;

        if not Trendy_Terminal.Init then
            return;
        end if;
        Trendy_Terminal.Set (Trendy_Terminal.Echo, False);
        Trendy_Terminal.Set (Trendy_Terminal.Line_Input, False);
        Trendy_Terminal.Set (Trendy_Terminal.Escape_Sequences, True);

        for Config of Configs loop
            if not SP.Commands.Run_Commands_From_File (Srch, To_String(Config)) then
                Put_Line ("Failing running commands from: " & To_String(Config));
                return;
            end if;
        end loop;

        loop
            Write_Prompt (Srch);
            Command_Line := Read_Command;
            if not SP.Commands.Execute (Srch, Command_Line) then
                Put_Line ("Unknown command");
            end if;
        end loop;

        --
        -- Trendy_Terminal.Shutdown;
    end Main;
end SP.Interactive;
