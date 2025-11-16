% Copyright 2025 The thrifty contributors
%
% Licensed under the Apache License, Version 2.0 (the "License");
% you may not use this file except in compliance with the License.
% You may obtain a copy of the License at
%
%     http://www.apache.org/licenses/LICENSE-2.0
%
% Unless required by applicable law or agreed to in writing, software
% distributed under the License is distributed on an "AS IS" BASIS,
% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
% See the License for the specific language governing permissions and
% limitations under the License.

-module(file_io_ffi).
-export([make_dir/1, write_file/2]).

-spec make_dir(binary()) -> {ok, atom()} | {error, atom()}.
make_dir(Path) ->
    case file:make_dir(Path) of
        ok ->
            {ok, ok};
        {error, eexist} ->
            {ok, ok};
        {error, Reason} ->
            {error, Reason}
    end.

-spec write_file(binary(), bitstring()) -> {ok, atom()} | {error, atom()}.
write_file(Path, Data) ->
    case file:write_file(Path, Data) of
        ok ->
            {ok, ok};
        {error, Reason} ->
            {error, Reason}
    end.
