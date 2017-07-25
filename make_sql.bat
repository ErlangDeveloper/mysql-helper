erl -s sql_version make
xcopy generation\include\*.hrl ..\..\..\erl\e_game_server\include\ /e /i /h /Y
xcopy generation\src\*.erl ..\..\..\erl\e_game_server\src\table\ /e /i /h /Y
pause