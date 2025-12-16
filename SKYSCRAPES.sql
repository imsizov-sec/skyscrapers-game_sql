CREATE OR REPLACE PACKAGE SKYSCRAPERS AS
    PROCEDURE START_MENU;

    PROCEDURE START_NEW_GAME(
        v_start_type IN NUMBER
    );

    PROCEDURE SELECT_GAME_FROM_CATALOG(
        v_seed IN NUMBER
    );

    PROCEDURE SELECT_GAME_BY_DIFFICULTY(
        v_difficulty_name IN VARCHAR2
    );

    PROCEDURE SET_SKYSCRAPER (
        v_coordinate_x     NUMBER,
        v_coordinate_y     NUMBER,
        v_value            NUMBER,
        v_is_mark          NUMBER DEFAULT 0 
    ); 

    PROCEDURE CHECK_PLAYING_FIELD_STATE;

    PROCEDURE GET_CELL_CANDIDATES (
        v_coordinate_x NUMBER,
        v_coordinate_y NUMBER
    );

    PROCEDURE GET_GAME_HISTORY (
        v_game_session_id NUMBER DEFAULT NULL
    );

    PROCEDURE UNDO;
    
    PROCEDURE REDO;

    PROCEDURE GAME_OVER;

    PROCEDURE EXPORT_GAME; 

    PROCEDURE IMPORT_GAME(
        v_export_data IN VARCHAR2
    );

    PROCEDURE GET_GAME_RULES;  
    
    PROCEDURE SHOW_LEADERBOARD;
    
   	PROCEDURE SHOW_DAILY_LEADERBOARD;
    
END SKYSCRAPERS;


CREATE OR REPLACE PACKAGE BODY SKYSCRAPERS AS

	----------------------------------------------------------
    PROCEDURE START_MENU IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE('=== ДОБРО ПОЖАЛОВАТЬ В ИГРУ "НЕБОСКРЁБЫ" ===');
    	DBMS_OUTPUT.PUT_LINE(' ');
        DBMS_OUTPUT.PUT_LINE('Доступные действия:');
        DBMS_OUTPUT.PUT_LINE(' ');
       
        DBMS_OUTPUT.PUT_LINE('1. Выбрать игру из каталога');
        DBMS_OUTPUT.PUT_LINE('   Процедура: SKYSCRAPERS.START_NEW_GAME(1);');
        DBMS_OUTPUT.PUT_LINE('   Описание: Выбор конкретной головоломки по её seed');
        DBMS_OUTPUT.PUT_LINE(' ');
       
    	DBMS_OUTPUT.PUT_LINE('2. Выбрать игру по сложности');
        DBMS_OUTPUT.PUT_LINE('   Процедура: SKYSCRAPERS.START_NEW_GAME(2);');
        DBMS_OUTPUT.PUT_LINE('   Описание: Случайная игра выбранного уровня сложности');
        DBMS_OUTPUT.PUT_LINE(' ');
       
        DBMS_OUTPUT.PUT_LINE('3. Игра дня');
        DBMS_OUTPUT.PUT_LINE('   Процедура: SKYSCRAPERS.START_NEW_GAME(3);');
        DBMS_OUTPUT.PUT_LINE('   Описание: Специальная ежедневная головоломка');
        DBMS_OUTPUT.PUT_LINE(' ');
       
        DBMS_OUTPUT.PUT_LINE('4. Импортировать игру');
        DBMS_OUTPUT.PUT_LINE('   Процедура: SKYSCRAPERS.START_NEW_GAME(4);');
        DBMS_OUTPUT.PUT_LINE('   Описание: Загрузка игры из экспортированной строки');
        DBMS_OUTPUT.PUT_LINE(' ');
       
        DBMS_OUTPUT.PUT_LINE('5. История игр');
        DBMS_OUTPUT.PUT_LINE('   Процедура: SKYSCRAPERS.GET_GAME_HISTORY();');
        DBMS_OUTPUT.PUT_LINE('   Описание: Просмотр истории завершённых игр');
    	DBMS_OUTPUT.PUT_LINE('   Для вывода всех игр необходимо вызвать процедуру без параметра');
    	DBMS_OUTPUT.PUT_LINE('   Для вывода истории ходов по конкретной игре необходимо передать в параметр');
    	DBMS_OUTPUT.PUT_LINE('   идентификатор конкретной игры');
        DBMS_OUTPUT.PUT_LINE(' ');
       
        DBMS_OUTPUT.PUT_LINE('6. Правила игры');
        DBMS_OUTPUT.PUT_LINE('   Процедура: SKYSCRAPERS.GET_GAME_RULES;');
        DBMS_OUTPUT.PUT_LINE('   Описание: Подробное описание правил игры');
        DBMS_OUTPUT.PUT_LINE(' ');
        
        DBMS_OUTPUT.PUT_LINE('7. Таблица лидеров');
        DBMS_OUTPUT.PUT_LINE('   Процедура: SKYSCRAPERS.SHOW_LEADERBOARD;');
        DBMS_OUTPUT.PUT_LINE('   Описание: Просмотр рейтинга игроков по суммарным очкам');
        DBMS_OUTPUT.PUT_LINE(' ');
       
       	DBMS_OUTPUT.PUT_LINE('8. Таблица лидеров игры дня');
        DBMS_OUTPUT.PUT_LINE('   Процедура: SKYSCRAPERS.SHOW_DAILY_LEADERBOARD();');
        DBMS_OUTPUT.PUT_LINE('   Описание: Общий рейтинг всех игроков в сегодняшней игре дня');
        DBMS_OUTPUT.PUT_LINE(' ');
       
        DBMS_OUTPUT.PUT_LINE('=============================================');
        DBMS_OUTPUT.PUT_LINE('Для выбора действия вызовите соответствующую процедуру');
        DBMS_OUTPUT.PUT_LINE('Пример:');
    	DBMS_OUTPUT.PUT_LINE('BEGIN');
    	DBMS_OUTPUT.PUT_LINE('	SKYSCRAPERS.START_NEW_GAME(1);');
    	DBMS_OUTPUT.PUT_LINE('END;');
		SKYSCRAPERS_UTILS.CRLF;
	EXCEPTION
        WHEN OTHERS THEN
            SKYSCRAPERS_UTILS.SAVE_LOG(NULL, 'ERROR', 'SKYSCRAPERS.START_MENU', 'Ошибка при получении стартового меню. SQLERRM: ' || SQLERRM);
			DBMS_OUTPUT.PUT_LINE('Ошибка при получении стартового меню.');
			SKYSCRAPERS_UTILS.CRLF;
    END START_MENU;
    ----------------------------------------------------------
      	
	----------------------------------------------------------
    PROCEDURE GET_GAME_RULES IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE('=== ПРАВИЛА ИГРЫ "НЕБОСКРЁБЫ" ===');
        DBMS_OUTPUT.PUT_LINE(' ');
        
        DBMS_OUTPUT.PUT_LINE('ОСНОВНЫЕ ПРАВИЛА:');
        DBMS_OUTPUT.PUT_LINE('1. Цель игры - заполнить поле небоскрёбами разной высоты');
        DBMS_OUTPUT.PUT_LINE('2. Размер поля может быть 4x4, 5x5, 6x6 или 7x7');
        DBMS_OUTPUT.PUT_LINE('3. В каждой клетке должен стоять небоскрёб высотой от 1 до N');
        DBMS_OUTPUT.PUT_LINE('   (где N - размер поля)');
        DBMS_OUTPUT.PUT_LINE(' ');
        
        DBMS_OUTPUT.PUT_LINE('ПРАВИЛО ЛАТИНСКОГО КВАДРАТА:');
        DBMS_OUTPUT.PUT_LINE('  - В каждой строке должны быть небоскрёбы разной высоты');
        DBMS_OUTPUT.PUT_LINE('  - В каждом столбце должны быть небоскрёбы разной высоты');
        DBMS_OUTPUT.PUT_LINE('  - То есть в строке/столбце не может быть двух одинаковых высот');
        DBMS_OUTPUT.PUT_LINE(' ');
        
        DBMS_OUTPUT.PUT_LINE('МЕХАНИЗМ ВИДИМОСТИ:');
        DBMS_OUTPUT.PUT_LINE('  - По краям поля расположены подсказки-цифры');
        DBMS_OUTPUT.PUT_LINE('  - Цифра показывает, сколько небоскрёбов видно с этой стороны');
        DBMS_OUTPUT.PUT_LINE('  - Небоскрёб виден, если он выше всех перед ним');
        DBMS_OUTPUT.PUT_LINE('  - Например: ряд [2, 4, 1, 3]');
        DBMS_OUTPUT.PUT_LINE('  - Слева видно 2 небоскрёба (2 и 4)');
        DBMS_OUTPUT.PUT_LINE('  - Справа видно 2 небоскрёба (3 и 4)');
        DBMS_OUTPUT.PUT_LINE(' ');
        
        DBMS_OUTPUT.PUT_LINE('ТИПЫ ХОДОВ:');
        DBMS_OUTPUT.PUT_LINE('  - Обычный ход - установка небоскрёба:');
        DBMS_OUTPUT.PUT_LINE('    SKYSCRAPERS.SET_SKYSCRAPER(x, y, значение, 0);');
        DBMS_OUTPUT.PUT_LINE('  - Пометка карандашом (для заметок):');
        DBMS_OUTPUT.PUT_LINE('    SKYSCRAPERS.SET_SKYSCRAPER(x, y, значение, 1);');
        DBMS_OUTPUT.PUT_LINE('  - Очистка клетки:');
        DBMS_OUTPUT.PUT_LINE('    SKYSCRAPERS.SET_SKYSCRAPER(x, y, 0, 0);');
        DBMS_OUTPUT.PUT_LINE(' ');
        
        DBMS_OUTPUT.PUT_LINE('ОГРАНИЧЕНИЯ ПО ВВОДУ:');
        DBMS_OUTPUT.PUT_LINE('  - Координаты x и y: от 1 до N (размера поля)');
        DBMS_OUTPUT.PUT_LINE('  - Значение небоскрёба: от 1 до N или 0 для очистки');
        DBMS_OUTPUT.PUT_LINE('  - Флаг пометки: 0 (обычный ход) или 1 (пометка)');
        DBMS_OUTPUT.PUT_LINE(' ');
        
        DBMS_OUTPUT.PUT_LINE('---');
        DBMS_OUTPUT.PUT_LINE('СИСТЕМА ПОДСЧЕТА ОЧКОВ (V_DAILY_BOARD):');
        DBMS_OUTPUT.PUT_LINE('Очки начисляются только за победу (Completed - Win) в зависимости от времени:');
        DBMS_OUTPUT.PUT_LINE('');
        
        DBMS_OUTPUT.PUT_LINE('4x4 (Easy):');
        DBMS_OUTPUT.PUT_LINE('  - < 5 мин: +5 очков');
        DBMS_OUTPUT.PUT_LINE('  - 5-10 мин: +3 очка');
        DBMS_OUTPUT.PUT_LINE('  - > 10 мин: +1 очко');
        
        DBMS_OUTPUT.PUT_LINE('5x5 (Medium):');
        DBMS_OUTPUT.PUT_LINE('  - < 7 мин: +6 очков');
        DBMS_OUTPUT.PUT_LINE('  - 7-15 мин: +4 очка');
        DBMS_OUTPUT.PUT_LINE('  - > 15 мин: +2 очка');
        
        DBMS_OUTPUT.PUT_LINE('6x6 (Hard):');
        DBMS_OUTPUT.PUT_LINE('  - < 10 мин: +8 очков');
        DBMS_OUTPUT.PUT_LINE('  - 10-15 мин: +5 очков');
        DBMS_OUTPUT.PUT_LINE('  - > 15 мин: +3 очка');
        
        DBMS_OUTPUT.PUT_LINE('7x7 (Expert):');
        DBMS_OUTPUT.PUT_LINE('  - < 15 мин: +10 очков');
        DBMS_OUTPUT.PUT_LINE('  - 15-25 мин: +7 очков');
        DBMS_OUTPUT.PUT_LINE('  - > 25 мин: +5 очков');
        DBMS_OUTPUT.PUT_LINE('');
        
        DBMS_OUTPUT.PUT_LINE('Проигрыш или незавершенная игра: +0 очков');
        DBMS_OUTPUT.PUT_LINE('---');
        
        DBMS_OUTPUT.PUT_LINE('ДОСТУПНЫЕ ПРОЦЕДУРЫ:');
        DBMS_OUTPUT.PUT_LINE('  - SKYSCRAPERS.START_MENU; - главное меню');
        DBMS_OUTPUT.PUT_LINE('  - SKYSCRAPERS.START_NEW_GAME(тип); - начать новую игру (при отсутствии активной сессии)');
        DBMS_OUTPUT.PUT_LINE('  - SKYSCRAPERS.SELECT_GAME_FROM_CATALOG(seed); - выбрать игру из каталога (при отсутствии активной сессии)');
        DBMS_OUTPUT.PUT_LINE('  - SKYSCRAPERS.SELECT_GAME_BY_DIFFICULTY(сложность); - выбрать игру по сложности (при отсутствии активной сессии)');
        DBMS_OUTPUT.PUT_LINE('  - SKYSCRAPERS.SET_SKYSCRAPER(x, y, значение, пометка); - совершить ход');
        DBMS_OUTPUT.PUT_LINE('  - SKYSCRAPERS.UNDO; - отмена последнего хода');
        DBMS_OUTPUT.PUT_LINE('  - SKYSCRAPERS.REDO; - восстановление отменённого хода');
        DBMS_OUTPUT.PUT_LINE('  - SKYSCRAPERS.CHECK_PLAYING_FIELD_STATE; - проверка состояния поля');
        DBMS_OUTPUT.PUT_LINE('  - SKYSCRAPERS.GET_CELL_CANDIDATES(x, y); - кандидаты для клетки');
        DBMS_OUTPUT.PUT_LINE('  - SKYSCRAPERS.GET_GAME_HISTORY; - история игр');
        DBMS_OUTPUT.PUT_LINE('  - SKYSCRAPERS.GAME_OVER; - досрочное завершение игры');
        DBMS_OUTPUT.PUT_LINE('  - SKYSCRAPERS.GET_GAME_RULES; - правила игры');
        DBMS_OUTPUT.PUT_LINE(' ');
        
        DBMS_OUTPUT.PUT_LINE('ПРИМЕРЫ ХОДОВ:');
        DBMS_OUTPUT.PUT_LINE('  - Установить небоскрёб высотой 4 в клетку (2, 3):');
        DBMS_OUTPUT.PUT_LINE('    BEGIN SKYSCRAPERS.SET_SKYSCRAPER(2, 3, 4, 0); END;');
        DBMS_OUTPUT.PUT_LINE('  - Поставить пометку 2 в клетку (1, 1):');
        DBMS_OUTPUT.PUT_LINE('    BEGIN SKYSCRAPERS.SET_SKYSCRAPER(1, 1, 2, 1); END;');
        DBMS_OUTPUT.PUT_LINE('  - Очистить клетку (3, 2):');
        DBMS_OUTPUT.PUT_LINE('    BEGIN SKYSCRAPERS.SET_SKYSCRAPER(3, 2, 0, 0); END;');
        DBMS_OUTPUT.PUT_LINE(' ');
        
        DBMS_OUTPUT.PUT_LINE('УДАЧИ В ИГРЕ!');
        SKYSCRAPERS_UTILS.CRLF;
        
    EXCEPTION
        WHEN OTHERS THEN
            SKYSCRAPERS_UTILS.SAVE_LOG(NULL, 'ERROR', 'SKYSCRAPERS.GET_GAME_RULES', 'Ошибка при выводе правил игры. SQLERRM: ' || SQLERRM);
            DBMS_OUTPUT.PUT_LINE('Ошибка при выводе правил игры.');
            SKYSCRAPERS_UTILS.CRLF;
    END GET_GAME_RULES;
    ----------------------------------------------------------
    
	----------------------------------------------------------
    PROCEDURE START_NEW_GAME(v_start_type IN NUMBER) IS
        v_daily_puzzle_id NUMBER;
        v_active_session NUMBER;
    BEGIN
        v_active_session := SKYSCRAPERS_UTILS.GET_ACTIVE_SESSION_ID(SKYSCRAPERS_UTILS.GET_ACTIVE_USER());
        IF v_active_session != -1 THEN
            DBMS_OUTPUT.PUT_LINE('Нельзя запустить новую игру во время активной игровой сессии!');
            DBMS_OUTPUT.PUT_LINE('Вы можете завершить текущую игру досрочно и начать новую.');
           	DBMS_OUTPUT.PUT_LINE('SKYSCRAPERS.GAME_OVER;');
			SKYSCRAPERS_UTILS.CRLF;
            RETURN;
        END IF;
        
        CASE v_start_type
            WHEN 1 THEN 
                DBMS_OUTPUT.PUT_LINE('=== ВЫБОР ИГРЫ ИЗ КАТАЛОГА ===');
                DBMS_OUTPUT.PUT_LINE('');
                DBMS_OUTPUT.PUT_LINE('Для выбора игры используйте:');
                DBMS_OUTPUT.PUT_LINE('SKYSCRAPERS.SELECT_GAME_FROM_CATALOG(seed);');
                DBMS_OUTPUT.PUT_LINE('');
                DBMS_OUTPUT.PUT_LINE('Доступные игры:');
                SKYSCRAPERS_UTILS.GET_GAME_CATALOG();
                
            WHEN 2 THEN 
                DBMS_OUTPUT.PUT_LINE('=== ВЫБОР ИГРЫ ПО СЛОЖНОСТИ ===');
                DBMS_OUTPUT.PUT_LINE('');
                DBMS_OUTPUT.PUT_LINE('Для выбора игры используйте:');
                DBMS_OUTPUT.PUT_LINE('SKYSCRAPERS.SELECT_GAME_BY_DIFFICULTY(difficulty_name);');
                DBMS_OUTPUT.PUT_LINE('');
                DBMS_OUTPUT.PUT_LINE('Доступные уровни сложности:');
                DBMS_OUTPUT.PUT_LINE('Easy - 4x4');
                DBMS_OUTPUT.PUT_LINE('Medium - 5x5');
                DBMS_OUTPUT.PUT_LINE('Hard - 6x6');
                DBMS_OUTPUT.PUT_LINE('Expert - 7x7');
                
            WHEN 3 THEN 
                DBMS_OUTPUT.PUT_LINE('=== ИГРА ДНЯ ===');
                DBMS_OUTPUT.PUT_LINE('');
                               
                BEGIN
                    SELECT ID INTO v_daily_puzzle_id 
                    FROM PUZZLES 
                    WHERE IS_DAILY = 1 
                    AND ROWNUM = 1;
                    
                 
                    SKYSCRAPERS_UTILS.START_GAME(v_daily_puzzle_id);
                    DBMS_OUTPUT.PUT_LINE(' ');
        			SKYSCRAPERS_UTILS.SHOW_HELP_PROMPT;
                    
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                    	SKYSCRAPERS_UTILS.SAVE_LOG(NULL, 'ERROR', 'SKYSCRAPERS.START_NEW_GAME', 'Игра дня не найдена');
                		RAISE_APPLICATION_ERROR(-20999, 'Ошибка: Игра дня не найдена.');
                END;
                
            WHEN 4 THEN 
                DBMS_OUTPUT.PUT_LINE('=== ИМПОРТ ИГРЫ ===');
                DBMS_OUTPUT.PUT_LINE('');
                DBMS_OUTPUT.PUT_LINE('Для импорта игры используйте:');
                DBMS_OUTPUT.PUT_LINE('SKYSCRAPERS.IMPORT_GAME(export_data);');
                DBMS_OUTPUT.PUT_LINE('');
                DBMS_OUTPUT.PUT_LINE('где export_data - строка данных экспортированной игры');
                
            ELSE
                DBMS_OUTPUT.PUT_LINE('Ошибка: Неизвестный тип запуска игры');
                DBMS_OUTPUT.PUT_LINE('Доступные типы: 1-выбор из каталога, 2-выбор по сложности, 3-игра дня, 4-импорт игры');
            	DBMS_OUTPUT.PUT_LINE('Для запуска игры необходимо вызвать следующую процедуру с номером типа: SKYSCRAPERS.START_NEW_GAME(type);');
        END CASE;
       
       	SKYSCRAPERS_UTILS.CRLF;
      
    EXCEPTION
        WHEN OTHERS THEN
	        IF SQLCODE = -20999 THEN
	        	DBMS_OUTPUT.PUT_LINE(SQLERRM);
	    	ELSE
	    		SKYSCRAPERS_UTILS.SAVE_LOG(NULL, 'ERROR', 'SKYSCRAPERS.START_NEW_GAME', 'Ошибка при запуске новой игры. Тип: ' || v_start_type || ', SQLERRM: ' || SQLERRM);
	            DBMS_OUTPUT.PUT_LINE('Ошибка при запуске новой игры.');
	    	END IF;
	    
	    	SKYSCRAPERS_UTILS.CRLF;
            
    END START_NEW_GAME;
    ----------------------------------------------------------
        
    ----------------------------------------------------------
    PROCEDURE SELECT_GAME_FROM_CATALOG(v_seed IN NUMBER) IS
        v_puzzle_id NUMBER;
    	v_active_session NUMBER;
    BEGIN
        
        SELECT ID INTO v_puzzle_id 
        FROM PUZZLES 
        WHERE RTRIM(SEED) = TO_CHAR(v_seed);
        
        v_active_session := SKYSCRAPERS_UTILS.GET_ACTIVE_SESSION_ID(SKYSCRAPERS_UTILS.GET_ACTIVE_USER());
        IF v_active_session != -1 THEN
            DBMS_OUTPUT.PUT_LINE('Нельзя запустить новую игру во время активной игровой сессии!');
            DBMS_OUTPUT.PUT_LINE('Вы можете завершить текущую игру досрочно и начать новую.');
    		SKYSCRAPERS_UTILS.CRLF;
            RETURN;
        END IF;
    
        SKYSCRAPERS_UTILS.START_GAME(v_puzzle_id);
        DBMS_OUTPUT.PUT_LINE(' ');
        SKYSCRAPERS_UTILS.SHOW_HELP_PROMPT;
        
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
        	SKYSCRAPERS_UTILS.SAVE_LOG(NULL, 'ERROR', 'SKYSCRAPERS.SELECT_GAME_FROM_CATALOG', 'Головоломка с seed ' || v_seed || ' не найдена');
            DBMS_OUTPUT.PUT_LINE('Ошибка: Головоломка с seed ' || v_seed || ' не найдена');
    		SKYSCRAPERS_UTILS.CRLF;
        WHEN TOO_MANY_ROWS THEN
            SKYSCRAPERS_UTILS.SAVE_LOG(NULL, 'ERROR', 'SKYSCRAPERS.SELECT_GAME_FROM_CATALOG', 'Несколько головоломок с seed ' || v_seed);
        	DBMS_OUTPUT.PUT_LINE('Ошибка при получении головоломки с seed ' || v_seed);
    		SKYSCRAPERS_UTILS.CRLF;
    	WHEN OTHERS THEN
    		IF SQLCODE = -20999 THEN
        		DBMS_OUTPUT.PUT_LINE(SQLERRM);
    		ELSE
    			SKYSCRAPERS_UTILS.SAVE_LOG(NULL, 'ERROR', 'SKYSCRAPERS.SELECT_GAME_FROM_CATALOG', 'Ошибка при выборе игры из каталога. Seed: ' || v_seed || ', SQLERRM: ' || SQLERRM);
            	DBMS_OUTPUT.PUT_LINE('Ошибка при выборе игры из каталога');
    		END IF;
    	
    		SKYSCRAPERS_UTILS.CRLF;
   
    END SELECT_GAME_FROM_CATALOG;
	----------------------------------------------------------
     
    ----------------------------------------------------------
    PROCEDURE SELECT_GAME_BY_DIFFICULTY(v_difficulty_name IN VARCHAR2) IS
        v_puzzle_id NUMBER;
    	v_active_session NUMBER;
    BEGIN
       
        SELECT ID INTO v_puzzle_id 
        FROM (
            SELECT p.ID
            FROM PUZZLES p
            JOIN DIFFICULTY_LEVELS dl ON p.DIFFICULTY_LEVEL_ID = dl.ID
            WHERE dl.DIFFICULTY_NAME = v_difficulty_name
            ORDER BY DBMS_RANDOM.VALUE
        )
        WHERE ROWNUM = 1;
    
    
        v_active_session := SKYSCRAPERS_UTILS.GET_ACTIVE_SESSION_ID(SKYSCRAPERS_UTILS.GET_ACTIVE_USER());
        IF v_active_session != -1 THEN
            DBMS_OUTPUT.PUT_LINE('Нельзя запустить новую игру во время активной игровой сессии!');
            DBMS_OUTPUT.PUT_LINE('Вы можете завершить текущую игру досрочно и начать новую.');
    		SKYSCRAPERS_UTILS.CRLF;
            RETURN;
        END IF;
        
        SKYSCRAPERS_UTILS.START_GAME(v_puzzle_id);
        DBMS_OUTPUT.PUT_LINE(' ');
        SKYSCRAPERS_UTILS.SHOW_HELP_PROMPT;
        
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
        	SKYSCRAPERS_UTILS.SAVE_LOG(NULL, 'ERROR', 'SKYSCRAPERS.SELECT_GAME_BY_DIFFICULTY', 'Головоломки со сложностью "' || v_difficulty_name || '" не найдены');
            DBMS_OUTPUT.PUT_LINE('Ошибка: Головоломки со сложностью "' || v_difficulty_name || '" не найдены');
    		SKYSCRAPERS_UTILS.CRLF;
        WHEN OTHERS THEN
        	IF SQLCODE = -20999 THEN
        		DBMS_OUTPUT.PUT_LINE(SQLERRM);
    		ELSE
    			SKYSCRAPERS_UTILS.SAVE_LOG(NULL, 'ERROR', 'SKYSCRAPERS.SELECT_GAME_BY_DIFFICULTY', 'Ошибка при выборе игры по сложности. difficulty_name: ' || v_difficulty_name || ', SQLERRM: ' || SQLERRM);
            	DBMS_OUTPUT.PUT_LINE('Ошибка при выборе игры по сложности');
    		END IF;
    	    
    		SKYSCRAPERS_UTILS.CRLF;
    END SELECT_GAME_BY_DIFFICULTY;
    ----------------------------------------------------------
    
    
    ----------------------------------------------------------
    PROCEDURE SET_SKYSCRAPER(
        v_coordinate_x IN NUMBER,
        v_coordinate_y IN NUMBER, 
        v_value IN NUMBER,
        v_is_mark IN NUMBER DEFAULT 0
    ) IS
        v_game_session_id NUMBER;
        v_puzzle_id NUMBER;
        v_win_result NUMBER;
        v_status_win_id NUMBER;
        v_field_size NUMBER;
    BEGIN
        v_game_session_id := SKYSCRAPERS_UTILS.GET_ACTIVE_SESSION_ID(SKYSCRAPERS_UTILS.GET_ACTIVE_USER());
        IF v_game_session_id = -1 THEN
            SKYSCRAPERS_UTILS.SAVE_LOG(NULL, 'ERROR', 'SKYSCRAPERS.SET_SKYSCRAPER', 'Попытка хода без активной сессии');
            RAISE_APPLICATION_ERROR(-20999, 'Ошибка: Активная игровая сессия не найдена.');
        END IF;
        
        
        SELECT gs.PUZZLE_ID, dl.SIZE_NUMBER INTO v_puzzle_id, v_field_size
        FROM GAME_SESSIONS gs
        JOIN PUZZLES p ON gs.PUZZLE_ID = p.ID
        JOIN DIFFICULTY_LEVELS dl ON p.DIFFICULTY_LEVEL_ID = dl.ID
        WHERE gs.ID = v_game_session_id;
        
        SKYSCRAPERS_UTILS.VALIDATE_MOVE_PARAMS(v_coordinate_x, v_coordinate_y, v_value, v_is_mark, v_field_size);
       
        
        SKYSCRAPERS_UTILS.DELETE_FUTURE_STEPS(v_game_session_id);
        
        
        UPDATE GAME_STEPS 
        SET IS_ACTUAL = 0 
        WHERE SESSION_ID = v_game_session_id;
        
        
        INSERT INTO GAME_STEPS (
            ID, SESSION_ID, ACTION_ID, COORDINATE_X, COORDINATE_Y, 
            VALUE, IS_ACTUAL, STEP_TIME, IS_MARK, IS_IMPORT, STEP_NUMBER
        ) VALUES (
            GAME_STEPS_SEQ.NEXTVAL, v_game_session_id, 
            CASE 
                WHEN v_is_mark = 1 THEN 2 
                WHEN v_value IS NULL OR v_value = 0 THEN 3  
                ELSE 1  
            END,
            v_coordinate_x, v_coordinate_y, 
            CASE WHEN v_value IS NULL THEN 0 ELSE v_value END,
            1, SYSDATE, v_is_mark, 0,
            (SELECT NVL(MAX(STEP_NUMBER), 0) + 1 FROM GAME_STEPS WHERE SESSION_ID = v_game_session_id)
        );
        
     
        IF v_is_mark = 0 AND (v_value IS NOT NULL AND v_value > 0) THEN
            UPDATE GAME_SESSIONS 
            SET STEPS_COUNT = STEPS_COUNT + 1 
            WHERE ID = v_game_session_id;
        END IF;
        
      
        DBMS_OUTPUT.PUT_LINE('=== ХОД УСПЕШНО ВЫПОЛНЕН ===');
        DBMS_OUTPUT.PUT_LINE('Клетка: (' || v_coordinate_x || ', ' || v_coordinate_y || ')');
        DBMS_OUTPUT.PUT_LINE('Действие: ' || 
            CASE 
                WHEN v_is_mark = 1 THEN 'установка пометки ' || v_value
                WHEN v_value = 0 THEN 'очистка клетки'
                ELSE 'установка небоскрёба высотой ' || v_value
            END);
        
     
        SKYSCRAPERS_UTILS.DRAW_PLAYING_FIELD(v_puzzle_id, v_game_session_id);
        
 
        IF v_is_mark = 0 AND (v_value IS NOT NULL AND v_value > 0) THEN
            v_win_result := SKYSCRAPERS_UTILS.CHECK_WIN(v_game_session_id, v_puzzle_id);
            
            IF v_win_result = 1 THEN

                SELECT ID INTO v_status_win_id FROM GAME_STATUSES WHERE NAME = 'Победа';
                SKYSCRAPERS_UTILS.END_GAME(v_status_win_id);
                DBMS_OUTPUT.PUT_LINE('Поздравляем! Вы выиграли!');
            	SKYSCRAPERS_UTILS.CRLF;
            	RETURN;
            END IF;
            
        END IF;
       
        SKYSCRAPERS_UTILS.CRLF;
        SKYSCRAPERS_UTILS.SHOW_AVAILABLE_ACTIONS();
        SKYSCRAPERS_UTILS.CRLF;
        
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -20999 THEN
                DBMS_OUTPUT.PUT_LINE(SQLERRM);
            ELSE
                SKYSCRAPERS_UTILS.SAVE_LOG(v_game_session_id, 'ERROR', 'SKYSCRAPERS.SET_SKYSCRAPER', 'Ошибка при установке небоскрёба. X: ' || v_coordinate_x || ', Y: ' || v_coordinate_y || ', Value: ' || v_value || ', Is_mark: ' || v_is_mark || ', SQLERRM: ' || SQLERRM);
                DBMS_OUTPUT.PUT_LINE('Ошибка при попытке совершить ход');
    			
            END IF;
           	
           	SKYSCRAPERS_UTILS.CRLF;
    END SET_SKYSCRAPER;
    ----------------------------------------------------------
    
    
	----------------------------------------------------------
    PROCEDURE CHECK_PLAYING_FIELD_STATE IS
        v_game_session_id NUMBER;
        v_puzzle_id NUMBER;
        v_field_size NUMBER;
        v_visible_count NUMBER;
        v_clue_value NUMBER;
        v_has_errors BOOLEAN := FALSE;
        v_field_matrix DBMS_SQL.NUMBER_TABLE;
    BEGIN
        v_game_session_id := SKYSCRAPERS_UTILS.GET_ACTIVE_SESSION_ID(SKYSCRAPERS_UTILS.GET_ACTIVE_USER());
        IF v_game_session_id = -1 THEN
            SKYSCRAPERS_UTILS.SAVE_LOG(NULL, 'ERROR', 'SKYSCRAPERS.CHECK_PLAYING_FIELD_STATE', 'Активная игровая сессия не найдена');
            RAISE_APPLICATION_ERROR(-20999, 'Ошибка: Активная игровая сессия не найдена.');
        END IF;
        
       
        SELECT gs.PUZZLE_ID, dl.SIZE_NUMBER INTO v_puzzle_id, v_field_size
        FROM GAME_SESSIONS gs
        JOIN PUZZLES p ON gs.PUZZLE_ID = p.ID
        JOIN DIFFICULTY_LEVELS dl ON p.DIFFICULTY_LEVEL_ID = dl.ID
        WHERE gs.ID = v_game_session_id;
        
        SKYSCRAPERS_UTILS.DRAW_PLAYING_FIELD(v_puzzle_id, v_game_session_id);
       
        v_field_matrix := SKYSCRAPERS_UTILS.GET_CURRENT_FIELD_MATRIX(v_game_session_id);
        
        DBMS_OUTPUT.PUT_LINE('=== ПРОВЕРКА СОСТОЯНИЯ ИГРОВОГО ПОЛЯ ===');
        

        FOR y IN 1..v_field_size LOOP
            FOR x1 IN 1..v_field_size LOOP
                IF SKYSCRAPERS_UTILS.GET_CELL_VALUE_FROM_MATRIX(v_field_matrix, v_field_size, x1, y) > 0 THEN
                    FOR x2 IN (x1+1)..v_field_size LOOP
                        IF SKYSCRAPERS_UTILS.GET_CELL_VALUE_FROM_MATRIX(v_field_matrix, v_field_size, x1, y) = 
                           SKYSCRAPERS_UTILS.GET_CELL_VALUE_FROM_MATRIX(v_field_matrix, v_field_size, x2, y) THEN
                            DBMS_OUTPUT.PUT_LINE('Ошибка: В строке ' || y || ' повтор значения ' || 
                                SKYSCRAPERS_UTILS.GET_CELL_VALUE_FROM_MATRIX(v_field_matrix, v_field_size, x1, y) || 
                                ' в столбцах ' || x1 || ' и ' || x2);
                            v_has_errors := TRUE;
                        END IF;
                    END LOOP;
                END IF;
            END LOOP;
        END LOOP;
        

        FOR x IN 1..v_field_size LOOP
            FOR y1 IN 1..v_field_size LOOP
                IF SKYSCRAPERS_UTILS.GET_CELL_VALUE_FROM_MATRIX(v_field_matrix, v_field_size, x, y1) > 0 THEN
                    FOR y2 IN (y1+1)..v_field_size LOOP
                        IF SKYSCRAPERS_UTILS.GET_CELL_VALUE_FROM_MATRIX(v_field_matrix, v_field_size, x, y1) = 
                           SKYSCRAPERS_UTILS.GET_CELL_VALUE_FROM_MATRIX(v_field_matrix, v_field_size, x, y2) THEN
                            DBMS_OUTPUT.PUT_LINE('Ошибка: В столбце ' || x || ' повтор значения ' || 
                                SKYSCRAPERS_UTILS.GET_CELL_VALUE_FROM_MATRIX(v_field_matrix, v_field_size, x, y1) || 
                                ' в строках ' || y1 || ' и ' || y2);
                            v_has_errors := TRUE;
                        END IF;
                    END LOOP;
                END IF;
            END LOOP;
        END LOOP;
        

        FOR i IN 1..v_field_size LOOP

            BEGIN
                SELECT VALUE INTO v_clue_value
                FROM CLUES 
                WHERE PUZZLE_ID = v_puzzle_id 
                AND SIDE = 'TOP' 
                AND CLUE_POSITION = i;
                
                v_visible_count := SKYSCRAPERS_UTILS.GET_VISIBLE_SKYSCRAPERS(i, 1, 'TOP', v_game_session_id);
                
                IF v_visible_count != v_clue_value THEN
                    DBMS_OUTPUT.PUT_LINE('Ошибка: Подсказка СВЕРХУ для столбца ' || i || ' нарушена (ожидалось: ' || v_clue_value || ', видно: ' || v_visible_count || ')');
                    v_has_errors := TRUE;
                END IF;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN NULL;
            END;
                

            BEGIN
                SELECT VALUE INTO v_clue_value
                FROM CLUES 
                WHERE PUZZLE_ID = v_puzzle_id 
                AND SIDE = 'BOTTOM' 
                AND CLUE_POSITION = i;
                
                v_visible_count := SKYSCRAPERS_UTILS.GET_VISIBLE_SKYSCRAPERS(i, v_field_size, 'BOTTOM', v_game_session_id);
                
                IF v_visible_count != v_clue_value THEN
                    DBMS_OUTPUT.PUT_LINE('Ошибка: Подсказка СНИЗУ для столбца ' || i || ' нарушена (ожидалось: ' || v_clue_value || ', видно: ' || v_visible_count || ')');
                    v_has_errors := TRUE;
                END IF;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN NULL;
            END;
                

            BEGIN
                SELECT VALUE INTO v_clue_value
                FROM CLUES 
                WHERE PUZZLE_ID = v_puzzle_id 
                AND SIDE = 'LEFT' 
                AND CLUE_POSITION = i;
                
                v_visible_count := SKYSCRAPERS_UTILS.GET_VISIBLE_SKYSCRAPERS(1, i, 'LEFT', v_game_session_id);
                
                IF v_visible_count != v_clue_value THEN
                    DBMS_OUTPUT.PUT_LINE('Ошибка: Подсказка СЛЕВА для строки ' || i || ' нарушена (ожидалось: ' || v_clue_value || ', видно: ' || v_visible_count || ')');
                    v_has_errors := TRUE;
                END IF;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN NULL;
            END;
                
 
            BEGIN
                SELECT VALUE INTO v_clue_value
                FROM CLUES 
                WHERE PUZZLE_ID = v_puzzle_id 
                AND SIDE = 'RIGHT' 
                AND CLUE_POSITION = i;
                
                v_visible_count := SKYSCRAPERS_UTILS.GET_VISIBLE_SKYSCRAPERS(v_field_size, i, 'RIGHT', v_game_session_id);
                
                IF v_visible_count != v_clue_value THEN
                    DBMS_OUTPUT.PUT_LINE('Ошибка: Подсказка СПРАВА для строки ' || i || ' нарушена (ожидалось: ' || v_clue_value || ', видно: ' || v_visible_count || ')');
                    v_has_errors := TRUE;
                END IF;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN NULL;
            END;
        END LOOP;
        

        DBMS_OUTPUT.PUT_LINE('');
        IF NOT v_has_errors THEN
            DBMS_OUTPUT.PUT_LINE('Нарушений не обнаружено! Поле заполнено корректно.');
        ELSE
            DBMS_OUTPUT.PUT_LINE('Обнаружены нарушения правил. Исправьте отмеченные ошибки.');
        END IF;
        
        DBMS_OUTPUT.PUT_LINE('');
        SKYSCRAPERS_UTILS.SHOW_HELP_PROMPT;
        SKYSCRAPERS_UTILS.CRLF;
        
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -20999 THEN
                DBMS_OUTPUT.PUT_LINE(SQLERRM);
            ELSE
                SKYSCRAPERS_UTILS.SAVE_LOG(v_game_session_id, 'ERROR', 'SKYSCRAPERS.CHECK_PLAYING_FIELD_STATE', 'Ошибка при проверке состояния поля. SQLERRM: ' || SQLERRM);
                DBMS_OUTPUT.PUT_LINE('Ошибка при проверке состояния поля.');
            END IF;
           
            SKYSCRAPERS_UTILS.CRLF;
    END CHECK_PLAYING_FIELD_STATE;
    ----------------------------------------------------------
    
    
	----------------------------------------------------------
    PROCEDURE GET_CELL_CANDIDATES(
        v_coordinate_x IN NUMBER,
        v_coordinate_y IN NUMBER
    ) IS
        v_game_session_id NUMBER;
        v_puzzle_id NUMBER;
        v_field_size NUMBER;
        v_candidates SYS.ODCINUMBERLIST := SYS.ODCINUMBERLIST();
        v_candidate_text VARCHAR2(1000);
        v_field_matrix DBMS_SQL.NUMBER_TABLE;
    BEGIN
        v_game_session_id := SKYSCRAPERS_UTILS.GET_ACTIVE_SESSION_ID(SKYSCRAPERS_UTILS.GET_ACTIVE_USER());
        IF v_game_session_id = -1 THEN
            SKYSCRAPERS_UTILS.SAVE_LOG(NULL, 'ERROR', 'SKYSCRAPERS.GET_CELL_CANDIDATES', 'Активная игровая сессия не найдена');
            RAISE_APPLICATION_ERROR(-20999, 'Ошибка: Активная игровая сессия не найдена.');
        END IF;
       
        SELECT gs.PUZZLE_ID, dl.SIZE_NUMBER INTO v_puzzle_id, v_field_size
        FROM GAME_SESSIONS gs
        JOIN PUZZLES p ON gs.PUZZLE_ID = p.ID
        JOIN DIFFICULTY_LEVELS dl ON p.DIFFICULTY_LEVEL_ID = dl.ID
        WHERE gs.ID = v_game_session_id;
        
        SKYSCRAPERS_UTILS.DRAW_PLAYING_FIELD(v_puzzle_id, v_game_session_id);
       

        SKYSCRAPERS_UTILS.VALIDATE_MOVE_PARAMS(v_coordinate_x, v_coordinate_y, 1, 0, v_field_size);
        

        v_field_matrix := SKYSCRAPERS_UTILS.GET_CURRENT_FIELD_MATRIX(v_game_session_id);
        
        FOR candidate_value IN 1..v_field_size LOOP
            IF SKYSCRAPERS_UTILS.IS_VALUE_POSSIBLE_IN_MATRIX(
                v_field_matrix, v_field_size, v_coordinate_x, v_coordinate_y, candidate_value
            ) THEN
                v_candidates.EXTEND;
                v_candidates(v_candidates.COUNT) := candidate_value;
            END IF;
        END LOOP;
        

        IF v_candidates.COUNT = 0 THEN
            v_candidate_text := 'нет разрешенных значений';
        ELSE
            v_candidate_text := '';
            FOR i IN 1..v_candidates.COUNT LOOP
                IF i = 1 THEN
                    v_candidate_text := TO_CHAR(v_candidates(i));
                ELSE
                    v_candidate_text := v_candidate_text || ', ' || TO_CHAR(v_candidates(i));
                END IF;
            END LOOP;
        END IF;
        

        DBMS_OUTPUT.PUT_LINE('=== КАНДИДАТЫ ДЛЯ ЯЧЕЙКИ (' || v_coordinate_x || ', ' || v_coordinate_y || ') ===');
        DBMS_OUTPUT.PUT_LINE('Разрешенные значения: ' || v_candidate_text);
        DBMS_OUTPUT.PUT_LINE('Количество кандидатов: ' || v_candidates.COUNT);
       
        DBMS_OUTPUT.PUT_LINE('');
        SKYSCRAPERS_UTILS.SHOW_HELP_PROMPT;
        SKYSCRAPERS_UTILS.CRLF;
        
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -20999 THEN
                DBMS_OUTPUT.PUT_LINE(SQLERRM);
            ELSE
                SKYSCRAPERS_UTILS.SAVE_LOG(v_game_session_id, 'ERROR', 'SKYSCRAPERS.GET_CELL_CANDIDATES', 'Ошибка при получении кандидатов для ячейки. X: ' || v_coordinate_x || ', Y: ' || v_coordinate_y || ', SQLERRM: ' || SQLERRM);
                DBMS_OUTPUT.PUT_LINE('Ошибка при получении кандидатов для ячейки.');
            END IF;
            
            SKYSCRAPERS_UTILS.CRLF;
    END GET_CELL_CANDIDATES;
    ----------------------------------------------------------
    
    ----------------------------------------------------------
    PROCEDURE GET_GAME_HISTORY(
        v_game_session_id IN NUMBER DEFAULT NULL
    ) IS
        v_user_id NUMBER;
    BEGIN
        v_user_id := SKYSCRAPERS_UTILS.GET_ACTIVE_USER();
        IF v_user_id = -1 THEN
            SKYSCRAPERS_UTILS.SAVE_LOG(NULL, 'ERROR', 'SKYSCRAPERS.GET_GAME_HISTORY', 'Пользователь не найден');
            RAISE_APPLICATION_ERROR(-20999, 'История игр не найдена.');
        END IF;
        
        IF v_game_session_id IS NOT NULL THEN
            SKYSCRAPERS_UTILS.SHOW_GAME_REPLAY(v_game_session_id, v_user_id);
        ELSE
            SKYSCRAPERS_UTILS.SHOW_GAMES_LIST(v_user_id);
        END IF;
        
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -20999 THEN
                DBMS_OUTPUT.PUT_LINE(SQLERRM);
            ELSE
                SKYSCRAPERS_UTILS.SAVE_LOG(NULL, 'ERROR', 'SKYSCRAPERS.GET_GAME_HISTORY', 'Ошибка при получении истории игр. Game_Session_ID: ' || v_game_session_id || ', SQLERRM: ' || SQLERRM);
                DBMS_OUTPUT.PUT_LINE('Ошибка при получении истории игр.');
            END IF;
           
            SKYSCRAPERS_UTILS.CRLF;
    END GET_GAME_HISTORY;
    ----------------------------------------------------------
    
    ----------------------------------------------------------
    PROCEDURE UNDO IS
        v_game_session_id NUMBER;
        v_puzzle_id NUMBER;
        v_last_step_id NUMBER;
        v_last_step_number NUMBER;
        v_previous_step_id NUMBER;
        v_field_size NUMBER;
    BEGIN
        v_game_session_id := SKYSCRAPERS_UTILS.GET_ACTIVE_SESSION_ID(SKYSCRAPERS_UTILS.GET_ACTIVE_USER());
        IF v_game_session_id = -1 THEN
            SKYSCRAPERS_UTILS.SAVE_LOG(NULL, 'ERROR', 'SKYSCRAPERS.UNDO', 'Активная игровая сессия не найдена');
            RAISE_APPLICATION_ERROR(-20999, 'Ошибка: Активная игровая сессия не найдена.');
        END IF;
        

        SELECT gs.PUZZLE_ID, dl.SIZE_NUMBER INTO v_puzzle_id, v_field_size
        FROM GAME_SESSIONS gs
        JOIN PUZZLES p ON gs.PUZZLE_ID = p.ID
        JOIN DIFFICULTY_LEVELS dl ON p.DIFFICULTY_LEVEL_ID = dl.ID
        WHERE gs.ID = v_game_session_id;
        

        BEGIN
            SELECT ID, STEP_NUMBER INTO v_last_step_id, v_last_step_number
            FROM GAME_STEPS
            WHERE SESSION_ID = v_game_session_id
            AND IS_ACTUAL = 1;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                DBMS_OUTPUT.PUT_LINE('Невозможно выполнить отмену хода, так как ни один ход ещё не был совершён!');
               	DBMS_OUTPUT.PUT_LINE('');
                SKYSCRAPERS_UTILS.DRAW_PLAYING_FIELD(v_puzzle_id, v_game_session_id);
               	DBMS_OUTPUT.PUT_LINE('');
        		SKYSCRAPERS_UTILS.SHOW_HELP_PROMPT;
                RETURN;
        END;
        

        IF v_last_step_number = 1 THEN
            DBMS_OUTPUT.PUT_LINE('Первый ход отменить нельзя!');
           	DBMS_OUTPUT.PUT_LINE('');
            SKYSCRAPERS_UTILS.DRAW_PLAYING_FIELD(v_puzzle_id, v_game_session_id);
            
        ELSE

            UPDATE GAME_STEPS 
            SET IS_ACTUAL = 0 
            WHERE ID = v_last_step_id;
            

            SELECT ID INTO v_previous_step_id
            FROM GAME_STEPS
            WHERE SESSION_ID = v_game_session_id
            AND STEP_NUMBER = v_last_step_number - 1;
            
            UPDATE GAME_STEPS 
            SET IS_ACTUAL = 1 
            WHERE ID = v_previous_step_id;
            

            UPDATE GAME_SESSIONS 
            SET STEPS_COUNT = GREATEST(STEPS_COUNT - 1, 0)
            WHERE ID = v_game_session_id;
            
            SKYSCRAPERS_UTILS.SAVE_LOG(v_game_session_id, 'INFO', 'SKYSCRAPERS.UNDO', 'Ход отменен. Step_ID: ' || v_last_step_id);
            
  
            DBMS_OUTPUT.PUT_LINE('Ход отменен. Состояние поля восстановлено.');
            SKYSCRAPERS_UTILS.DRAW_PLAYING_FIELD(v_puzzle_id, v_game_session_id);
        END IF;
       
        DBMS_OUTPUT.PUT_LINE('');
        SKYSCRAPERS_UTILS.SHOW_HELP_PROMPT;
        
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -20999 THEN
                DBMS_OUTPUT.PUT_LINE(SQLERRM);
            ELSE
                SKYSCRAPERS_UTILS.SAVE_LOG(v_game_session_id, 'ERROR', 'SKYSCRAPERS.UNDO', 'Ошибка при отмене хода. SQLERRM: ' || SQLERRM);
                DBMS_OUTPUT.PUT_LINE('Ошибка при отмене хода.');
            END IF;
           
            SKYSCRAPERS_UTILS.CRLF;
    END UNDO;
    ----------------------------------------------------------
    
    
        ----------------------------------------------------------
    PROCEDURE REDO IS
        v_game_session_id NUMBER;
        v_puzzle_id NUMBER;
        v_field_size NUMBER;
        v_current_step_id NUMBER;
        v_current_step_number NUMBER;
        v_next_step_id NUMBER;
        v_next_step_number NUMBER;
        v_has_current_step BOOLEAN := TRUE;
    BEGIN

        v_game_session_id := SKYSCRAPERS_UTILS.GET_ACTIVE_SESSION_ID(SKYSCRAPERS_UTILS.GET_ACTIVE_USER());
        IF v_game_session_id = -1 THEN
            SKYSCRAPERS_UTILS.SAVE_LOG(NULL, 'ERROR', 'SKYSCRAPERS.REDO', 'Активная игровая сессия не найдена');
            RAISE_APPLICATION_ERROR(-20999, 'Ошибка: Активная игровая сессия не найдена.');
        END IF;
        

        SELECT gs.PUZZLE_ID, dl.SIZE_NUMBER INTO v_puzzle_id, v_field_size
        FROM GAME_SESSIONS gs
        JOIN PUZZLES p ON gs.PUZZLE_ID = p.ID
        JOIN DIFFICULTY_LEVELS dl ON p.DIFFICULTY_LEVEL_ID = dl.ID
        WHERE gs.ID = v_game_session_id;
        

        BEGIN
            SELECT ID, STEP_NUMBER INTO v_current_step_id, v_current_step_number
            FROM GAME_STEPS
            WHERE SESSION_ID = v_game_session_id
            AND IS_ACTUAL = 1;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN

                v_current_step_number := 0;
                v_has_current_step := FALSE;
        END;
        

        IF v_has_current_step THEN
            v_next_step_number := v_current_step_number + 1;
        ELSE
            v_next_step_number := 1;  
        END IF;
        

        BEGIN
            SELECT ID, STEP_NUMBER INTO v_next_step_id, v_next_step_number
            FROM GAME_STEPS
            WHERE SESSION_ID = v_game_session_id
            AND STEP_NUMBER = v_next_step_number;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                DBMS_OUTPUT.PUT_LINE('Невозможно выполнить восстановление хода!');
               	DBMS_OUTPUT.PUT_LINE('Отменённые ходы отсутствуют!');
                DBMS_OUTPUT.PUT_LINE('');
                SKYSCRAPERS_UTILS.DRAW_PLAYING_FIELD(v_puzzle_id, v_game_session_id);
                DBMS_OUTPUT.PUT_LINE('');
        		SKYSCRAPERS_UTILS.SHOW_HELP_PROMPT;
                RETURN;
        END;
        

        IF v_has_current_step THEN
            UPDATE GAME_STEPS 
            SET IS_ACTUAL = 0 
            WHERE ID = v_current_step_id;
        END IF;
        

        UPDATE GAME_STEPS 
        SET IS_ACTUAL = 1 
        WHERE ID = v_next_step_id;
        
  
        UPDATE GAME_SESSIONS 
        SET STEPS_COUNT = STEPS_COUNT + 1 
        WHERE ID = v_game_session_id
        AND EXISTS (
            SELECT 1 
            FROM GAME_STEPS 
            WHERE ID = v_next_step_id 
            AND IS_MARK = 0 
            AND VALUE IS NOT NULL 
            AND VALUE > 0
        );
        
        SKYSCRAPERS_UTILS.SAVE_LOG(v_game_session_id, 'INFO', 'SKYSCRAPERS.REDO', 'Ход восстановлен. Step_ID: ' || v_next_step_id);
        
        DBMS_OUTPUT.PUT_LINE('Ход восстановлен. Текущее поле обновлено.');
       	DBMS_OUTPUT.PUT_LINE('');
        SKYSCRAPERS_UTILS.DRAW_PLAYING_FIELD(v_puzzle_id, v_game_session_id);
        

        IF SKYSCRAPERS_UTILS.CHECK_WIN(v_game_session_id, v_puzzle_id) = 1 THEN
            DECLARE
                v_status_win_id NUMBER;
            BEGIN
                SELECT ID INTO v_status_win_id FROM GAME_STATUSES WHERE NAME = 'Победа';
                SKYSCRAPERS_UTILS.END_GAME(v_status_win_id);
                DBMS_OUTPUT.PUT_LINE('Поздравляем! Вы выиграли!');
                SKYSCRAPERS_UTILS.CRLF;
            END;
        END IF;
        
        DBMS_OUTPUT.PUT_LINE('');
        SKYSCRAPERS_UTILS.SHOW_HELP_PROMPT;
       
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -20999 THEN
                DBMS_OUTPUT.PUT_LINE(SQLERRM);
            ELSE
                SKYSCRAPERS_UTILS.SAVE_LOG(v_game_session_id, 'ERROR', 'SKYSCRAPERS.REDO', 'Ошибка при восстановлении хода. SQLERRM: ' || SQLERRM);
                DBMS_OUTPUT.PUT_LINE('Ошибка при восстановлении хода.');
            END IF;
           
            SKYSCRAPERS_UTILS.CRLF;
    END REDO;
    ----------------------------------------------------------
    
   
   
    
	----------------------------------------------------------
	PROCEDURE GAME_OVER IS
		v_game_session_id NUMBER;
		v_status_id NUMBER;
	BEGIN
		v_game_session_id := SKYSCRAPERS_UTILS.GET_ACTIVE_SESSION_ID(SKYSCRAPERS_UTILS.GET_ACTIVE_USER());
		IF v_game_session_id = -1 THEN
			SKYSCRAPERS_UTILS.SAVE_LOG(NULL, 'ERROR', 'SKYSCRAPERS.GAME_OVER', 'Активная игровая сессия не найдена');
			RAISE_APPLICATION_ERROR(-20999, 'Ошибка: Активная игровая сессия не найдена.');
		END IF;
		
		SELECT ID INTO v_status_id
		FROM GAME_STATUSES 
		WHERE NAME = 'Завершена';
		
		SKYSCRAPERS_UTILS.END_GAME(v_status_id);
		
		SKYSCRAPERS_UTILS.SAVE_LOG(v_game_session_id, 'INFO', 'SKYSCRAPERS.GAME_OVER', 'Игра завершена досрочно');
		
		DBMS_OUTPUT.PUT_LINE('=== ИГРА ОКОНЧЕНА ДОСРОЧНО ===');
		DBMS_OUTPUT.PUT_LINE('Спасибо за игру!');
	   
		DBMS_OUTPUT.PUT_LINE('');
		SKYSCRAPERS_UTILS.SHOW_HELP_PROMPT;
		SKYSCRAPERS_UTILS.CRLF;
		
	EXCEPTION
		WHEN OTHERS THEN
			IF SQLCODE = -20999 THEN
				DBMS_OUTPUT.PUT_LINE(SQLERRM);
			ELSE
				SKYSCRAPERS_UTILS.SAVE_LOG(v_game_session_id, 'ERROR', 'SKYSCRAPERS.GAME_OVER', 'Ошибка при досрочном завершении игры. SQLERRM: ' || SQLERRM);
				DBMS_OUTPUT.PUT_LINE('Ошибка при завершении игры.');
			END IF;
		   
			SKYSCRAPERS_UTILS.CRLF;
	END GAME_OVER;
	----------------------------------------------------------
   

   	
   
	----------------------------------------------------------
	PROCEDURE EXPORT_GAME IS
		v_game_session_id NUMBER;
		v_puzzle_id NUMBER;
		v_export_string VARCHAR2(4000);
		v_status_export_id NUMBER;
		
		CURSOR c_moves IS
			SELECT 
				gs.COORDINATE_X, 
				gs.COORDINATE_Y, 
				gs.VALUE, 
				gs.IS_MARK,
				gs.STEP_NUMBER
			FROM GAME_STEPS gs
			WHERE gs.SESSION_ID = v_game_session_id
			ORDER BY gs.STEP_NUMBER ASC;
			
	BEGIN
		v_game_session_id := SKYSCRAPERS_UTILS.GET_ACTIVE_SESSION_ID(SKYSCRAPERS_UTILS.GET_ACTIVE_USER());
		IF v_game_session_id = -1 THEN
			RAISE_APPLICATION_ERROR(-20999, 'Ошибка: Активная игровая сессия не найдена.');
		END IF;

		SELECT PUZZLE_ID INTO v_puzzle_id
		FROM GAME_SESSIONS gs
		WHERE gs.ID = v_game_session_id;

		-- Формируем экспортную строку
		v_export_string := TO_CHAR(v_puzzle_id);

		FOR r_move IN c_moves LOOP
			v_export_string := v_export_string || '|' ||
							   r_move.COORDINATE_X || ',' ||
							   r_move.COORDINATE_Y || ',' ||
							   COALESCE(TO_CHAR(r_move.VALUE), '0') || ',' ||
							   r_move.IS_MARK || ',' ||
							   r_move.STEP_NUMBER;
		END LOOP;

		-- Получаем ID статуса "Экспорт" и завершаем игру
		SELECT ID INTO v_status_export_id 
		FROM GAME_STATUSES 
		WHERE NAME = 'Экспорт';
		
		SKYSCRAPERS_UTILS.END_GAME(v_status_export_id);

		DBMS_OUTPUT.PUT_LINE('=== ЭКСПОРТ ИГРЫ УСПЕШЕН ===');
		DBMS_OUTPUT.PUT_LINE('Скопируйте строку для импорта на другом компьютере:');
		DBMS_OUTPUT.PUT_LINE(v_export_string);
		DBMS_OUTPUT.PUT_LINE('');
		DBMS_OUTPUT.PUT_LINE('Игра завершена со статусом "Экспорт".');
		SKYSCRAPERS_UTILS.CRLF;

	EXCEPTION
		WHEN OTHERS THEN
			IF SQLCODE = -20999 THEN
				DBMS_OUTPUT.PUT_LINE(SQLERRM);
			ELSE
				SKYSCRAPERS_UTILS.SAVE_LOG(v_game_session_id, 'ERROR', 'SKYSCRAPERS.EXPORT_GAME', 'Ошибка при экспорте игры. SQLERRM: ' || SQLERRM);
				RAISE_APPLICATION_ERROR(-20999, 'Ошибка при экспорте игры.');
			END IF;
	END EXPORT_GAME;
	----------------------------------------------------------
    
   
   
   
    ----------------------------------------------------------
	PROCEDURE IMPORT_GAME(v_export_data IN VARCHAR2) IS
	BEGIN
		-- Проверяем, что строка не пустая
		IF v_export_data IS NULL OR LENGTH(TRIM(v_export_data)) = 0 THEN
			RAISE_APPLICATION_ERROR(-20999, 'Ошибка: Передана пустая строка для импорта.');
		END IF;

		-- Проверяем, нет ли активной сессии
		IF SKYSCRAPERS_UTILS.GET_ACTIVE_SESSION_ID(SKYSCRAPERS_UTILS.GET_ACTIVE_USER()) != -1 THEN
			RAISE_APPLICATION_ERROR(-20999, 'Ошибка: Невозможно импортировать игру, пока активна другая сессия.');
		END IF;
		
		-- Вызываем утилиту для импорта
		SKYSCRAPERS_UTILS.IMPORT_GAME(v_export_data);
	
	EXCEPTION
		WHEN OTHERS THEN
			IF SQLCODE = -20999 THEN
				DBMS_OUTPUT.PUT_LINE(SQLERRM);
			ELSE
				SKYSCRAPERS_UTILS.SAVE_LOG(NULL, 'ERROR', 'SKYSCRAPERS.IMPORT_GAME', 'Ошибка при импорте игры. SQLERRM: ' || SQLERRM);
				RAISE_APPLICATION_ERROR(-20999, 'Ошибка при импорте игры.');
			END IF;
	END IMPORT_GAME;
	----------------------------------------------------------
   
   
   

   
    ----------------------------------------------------------
	PROCEDURE SHOW_LEADERBOARD IS
	    CURSOR leaderboard_cursor IS
	        SELECT
	            USERNAME,
	            TOTAL_SCORE,
	            LAST_GAME_DIFFICULTY,
	            LAST_GAME_TIME
	        FROM
	            V_LEADERBOARD;
	
	    v_rank NUMBER := 1;
	BEGIN

	    
	    SKYSCRAPERS_UTILS.CRLF;
	    DBMS_OUTPUT.PUT_LINE('=== ТАБЛИЦА ЛИДЕРОВ ===');
	    SKYSCRAPERS_UTILS.CRLF;
	

	    DBMS_OUTPUT.PUT_LINE(RPAD('=', 100, '='));
	    DBMS_OUTPUT.PUT_LINE(
	        RPAD('МЕСТО', 5) || ' | ' ||
	        RPAD('ИГРОК', 20) || ' | ' ||
	        RPAD('ВСЕГО ОЧКОВ', 15) || ' | ' ||
	        RPAD('ПОСЛЕДНЯЯ ИГРА', 15)
	    );
	    DBMS_OUTPUT.PUT_LINE(RPAD('=', 100, '='));
	

	    FOR rec IN leaderboard_cursor LOOP
	        DBMS_OUTPUT.PUT_LINE(
	            RPAD(v_rank, 5) || ' | ' ||
	            RPAD(rec.USERNAME, 20) || ' | ' ||
	            RPAD(TO_CHAR(rec.TOTAL_SCORE, '99999'), 15) || ' | ' ||
	            TO_CHAR(rec.LAST_GAME_TIME, 'YYYY-MM-DD HH24:MI')
	        );
	        v_rank := v_rank + 1;
	    END LOOP;
	    
	    IF v_rank = 1 THEN
	        DBMS_OUTPUT.PUT_LINE('Табло лидеров пусто. Нет завершенных игр с очками.');
	    END IF;
	
	    DBMS_OUTPUT.PUT_LINE(RPAD('=', 100, '='));
	    SKYSCRAPERS_UTILS.CRLF;
	    SKYSCRAPERS_UTILS.SHOW_HELP_PROMPT; 
	    SKYSCRAPERS_UTILS.CRLF;
	END SHOW_LEADERBOARD;
	----------------------------------------------------------




	----------------------------------------------------------
	PROCEDURE SHOW_DAILY_LEADERBOARD IS
		v_daily_puzzle_id NUMBER;
		v_daily_puzzle_seed CHAR(10);
		v_difficulty_name VARCHAR2(50);
		v_grid_size VARCHAR2(10);
		v_leader_count NUMBER := 0;
	BEGIN
		-- Получаем информацию об игре дня
		BEGIN
			SELECT p.ID, p.SEED, dl.DIFFICULTY_NAME, dl.SIZE_NUMBER || 'x' || dl.SIZE_NUMBER
			INTO v_daily_puzzle_id, v_daily_puzzle_seed, v_difficulty_name, v_grid_size
			FROM PUZZLES p
			JOIN DIFFICULTY_LEVELS dl ON p.DIFFICULTY_LEVEL_ID = dl.ID
			WHERE p.IS_DAILY = 1
			AND ROWNUM = 1;
		EXCEPTION
			WHEN NO_DATA_FOUND THEN
				DBMS_OUTPUT.PUT_LINE('Игра дня еще не установлена!');
				DBMS_OUTPUT.PUT_LINE('Обратитесь к администратору.');
				SKYSCRAPERS_UTILS.CRLF;
				RETURN;
		END;
		
		DBMS_OUTPUT.PUT_LINE('=== ТАБЛИЦА ЛИДЕРОВ ИГРЫ ДНЯ ===');
		DBMS_OUTPUT.PUT_LINE('Дата: ' || TO_CHAR(SYSDATE, 'DD.MM.YYYY'));
		DBMS_OUTPUT.PUT_LINE('Сложность: ' || v_difficulty_name);
		DBMS_OUTPUT.PUT_LINE('Размер: ' || v_grid_size);
		DBMS_OUTPUT.PUT_LINE('Seed: ' || v_daily_puzzle_seed);
		DBMS_OUTPUT.PUT_LINE('');
		DBMS_OUTPUT.PUT_LINE('Правила:');
		DBMS_OUTPUT.PUT_LINE('- Только победы за сегодня учитываются в рейтинге');
		DBMS_OUTPUT.PUT_LINE('- Чем быстрее победа - тем выше место');
		DBMS_OUTPUT.PUT_LINE('- При равных очках выше тот, кто быстрее');
		DBMS_OUTPUT.PUT_LINE('');
		
		-- Проверяем, есть ли лидеры
		SELECT COUNT(*) INTO v_leader_count
		FROM V_DAILY_BOARD;
		
		IF v_leader_count = 0 THEN
			DBMS_OUTPUT.PUT_LINE('Пока нет победителей в игре дня!');
			DBMS_OUTPUT.PUT_LINE('Будьте первым - сыграйте и победите!');
			SKYSCRAPERS_UTILS.CRLF;
			RETURN;
		END IF;
		
		DBMS_OUTPUT.PUT_LINE(RPAD('=', 110, '='));
		DBMS_OUTPUT.PUT_LINE(
			RPAD('МЕСТО', 6) || ' | ' ||
			RPAD('ИГРОК', 20) || ' | ' ||
			RPAD('НАЧАЛО', 17) || ' | ' ||
			RPAD('КОНЕЦ', 17) || ' | ' ||
			RPAD('ДЛИТЕЛЬНОСТЬ', 20) || ' | ' ||
			RPAD('ОЧКИ', 6)
		);
		DBMS_OUTPUT.PUT_LINE(RPAD('=', 110, '='));
		
		FOR rec IN (
			SELECT 
				RANK,
				USERNAME,
				START_TIME,
				END_TIME,
				GAME_DURATION,
				SCORE
			FROM V_DAILY_BOARD
			ORDER BY RANK
		) LOOP
			DBMS_OUTPUT.PUT_LINE(
				RPAD('   ' || rec.RANK, 6) || ' | ' ||
				RPAD(rec.USERNAME, 20) || ' | ' ||
				RPAD(TO_CHAR(rec.START_TIME, 'HH24:MI:SS'), 17) || ' | ' ||
				RPAD(TO_CHAR(rec.END_TIME, 'HH24:MI:SS'), 17) || ' | ' ||
				RPAD(rec.GAME_DURATION, 20) || ' | ' ||
				RPAD(TO_CHAR(rec.SCORE, '999'), 6)
			);
		END LOOP;
		
		DBMS_OUTPUT.PUT_LINE(RPAD('=', 110, '='));
		
		-- Статистика текущего пользователя (если есть)
		DECLARE
			v_user_rank NUMBER;
			v_user_score NUMBER;
			v_user_duration VARCHAR2(100);
		BEGIN
			SELECT RANK, SCORE, GAME_DURATION 
			INTO v_user_rank, v_user_score, v_user_duration
			FROM V_DAILY_BOARD
			WHERE USERNAME = SYS_CONTEXT('USERENV', 'SESSION_USER')
			AND ROWNUM = 1;
			
			DBMS_OUTPUT.PUT_LINE('');
			DBMS_OUTPUT.PUT_LINE('=== ВАШЕ МЕСТО ===');
			DBMS_OUTPUT.PUT_LINE('Место: ' || v_user_rank || 
				CASE 
					WHEN v_user_rank = 1 THEN ' (ПЕРВОЕ МЕСТО!)'
					WHEN v_user_rank <= 3 THEN ' (ПРИЗОВОЕ МЕСТО!)'
					WHEN v_user_rank <= 10 THEN ' (ТОП-10!)'
					ELSE ''
				END);
			DBMS_OUTPUT.PUT_LINE('Очки: ' || v_user_score);
			DBMS_OUTPUT.PUT_LINE('Время: ' || v_user_duration);
			
			-- Подсказка для улучшения
			IF v_user_rank > 1 THEN
				DECLARE
					v_best_time VARCHAR2(100);
				BEGIN
					SELECT GAME_DURATION INTO v_best_time
					FROM V_DAILY_BOARD
					WHERE RANK = 1;
					
					DBMS_OUTPUT.PUT_LINE('');
					DBMS_OUTPUT.PUT_LINE('Чтобы занять первое место:');
					DBMS_OUTPUT.PUT_LINE('Лучшее время: ' || v_best_time);
					DBMS_OUTPUT.PUT_LINE('Ваше время: ' || v_user_duration);
				END;
			END IF;
			
		EXCEPTION
			WHEN NO_DATA_FOUND THEN
				DBMS_OUTPUT.PUT_LINE('');
				DBMS_OUTPUT.PUT_LINE('=== ВАШЕ МЕСТО ===');
				DBMS_OUTPUT.PUT_LINE('Вы еще не играли сегодня в игру дня!');
				DBMS_OUTPUT.PUT_LINE('Чтобы попасть в таблицу лидеров:');
				DBMS_OUTPUT.PUT_LINE('1. Начните игру дня: SKYSCRAPERS.START_NEW_GAME(3);');
				DBMS_OUTPUT.PUT_LINE('2. Завершите игру победой');
		END;
		
		DBMS_OUTPUT.PUT_LINE('');
		DBMS_OUTPUT.PUT_LINE('Игра дня обновляется каждый день в 00:00');
		DBMS_OUTPUT.PUT_LINE('Успейте сыграть до сброса!');
		
		SKYSCRAPERS_UTILS.CRLF;
		SKYSCRAPERS_UTILS.SHOW_HELP_PROMPT;
		SKYSCRAPERS_UTILS.CRLF;
		
	EXCEPTION
		WHEN OTHERS THEN
			SKYSCRAPERS_UTILS.SAVE_LOG(NULL, 'ERROR', 'SKYSCRAPERS.SHOW_DAILY_LEADERBOARD', 'Ошибка при выводе таблицы лидеров игры дня. SQLERRM: ' || SQLERRM);
			DBMS_OUTPUT.PUT_LINE('Ошибка при выводе таблицы лидеров игры дня.');
			SKYSCRAPERS_UTILS.CRLF;
	END SHOW_DAILY_LEADERBOARD;
	----------------------------------------------------------
END SKYSCRAPERS;