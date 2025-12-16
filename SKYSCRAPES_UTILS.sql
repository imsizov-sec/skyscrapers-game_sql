CREATE OR REPLACE PACKAGE SKYSCRAPERS_UTILS AS
    PROCEDURE START_GAME(
        v_puzzle_id IN NUMBER
    );

    PROCEDURE END_GAME(
        v_game_status_id IN NUMBER
    );

    PROCEDURE DRAW_PLAYING_FIELD(
        v_puzzle_id IN NUMBER,
        v_game_session_id IN NUMBER DEFAULT NULL
    );
    
    PROCEDURE SAVE_LOG(
        v_game_session_id IN NUMBER,
        v_log_type IN VARCHAR2,
        v_procedure_name IN VARCHAR2,
        v_message IN VARCHAR2
    );
    
    PROCEDURE GET_GAME_CATALOG;
    
    FUNCTION GET_ACTIVE_SESSION_ID(
        v_user_id IN NUMBER
    ) RETURN NUMBER;
    
    FUNCTION GET_ACTIVE_USER RETURN NUMBER;
    
    FUNCTION CHECK_WIN(
        v_game_session_id IN NUMBER,
        v_puzzle_id IN NUMBER
    ) RETURN NUMBER;
    
    PROCEDURE GET_MOVE_PROMT;
    
    PROCEDURE VALIDATE_MOVE_PARAMS(
        v_coordinate_x IN NUMBER,
        v_coordinate_y IN NUMBER, 
        v_value IN NUMBER,
        v_is_mark IN NUMBER,
        v_field_size IN NUMBER
    );
    
    FUNCTION GET_VISIBLE_SKYSCRAPERS(
        v_coordinate_x IN NUMBER,
        v_coordinate_y IN NUMBER, 
        v_side IN VARCHAR2,
        v_game_session_id IN NUMBER
    ) RETURN NUMBER;
    
    FUNCTION GET_CURRENT_FIELD_MATRIX(
        v_game_session_id IN NUMBER
    ) RETURN DBMS_SQL.NUMBER_TABLE;
    
    FUNCTION GET_CELL_VALUE_FROM_MATRIX(
        v_field_matrix IN DBMS_SQL.NUMBER_TABLE,
        v_field_size IN NUMBER,
        v_coordinate_x IN NUMBER,
        v_coordinate_y IN NUMBER
    ) RETURN NUMBER;
    
    FUNCTION IS_VALUE_POSSIBLE_IN_MATRIX(
        v_field_matrix IN DBMS_SQL.NUMBER_TABLE,
        v_field_size IN NUMBER,
        v_coordinate_x IN NUMBER,
        v_coordinate_y IN NUMBER,
        v_value IN NUMBER
    ) RETURN BOOLEAN;
    
    PROCEDURE SHOW_GAMES_LIST(
        v_user_id IN NUMBER
    );
    
    PROCEDURE SHOW_GAME_REPLAY(
        v_game_session_id IN NUMBER,
        v_user_id IN NUMBER
    );
    
    PROCEDURE CRLF;
    
    PROCEDURE CHECK_USER_ACTIVE_GAME;
    
    PROCEDURE SET_DAILY_GAME;
   
    PROCEDURE SHOW_HELP_PROMPT;
   
    PROCEDURE DELETE_FUTURE_STEPS(
        v_game_session_id IN NUMBER
    );
    
        
    PROCEDURE IMPORT_GAME(
        v_export_data IN VARCHAR2
    );
    
    FUNCTION CALCULATE_SCORE(
        v_size_number IN NUMBER,
        v_duration_minutes IN NUMBER,
        v_status_name IN VARCHAR2
    ) RETURN NUMBER;
    
   	PROCEDURE SHOW_AVAILABLE_ACTIONS;
   
    FUNCTION FORMAT_GAME_DURATION(
   		v_start_time IN DATE,
   		v_end_time IN DATE DEFAULT SYSDATE
   	) RETURN VARCHAR2;
    
END SKYSCRAPERS_UTILS;


CREATE OR REPLACE PACKAGE BODY SKYSCRAPERS_UTILS AS

	----------------------------------------------------------
	PROCEDURE START_GAME(v_puzzle_id IN NUMBER) IS
        v_game_session_id NUMBER DEFAULT NULL;
        v_user_id NUMBER;
        v_status_id NUMBER;
        v_active_session NUMBER;
        v_puzzle_exists NUMBER;
    BEGIN
        BEGIN
            SELECT 1 INTO v_puzzle_exists FROM PUZZLES WHERE ID = v_puzzle_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                SAVE_LOG(NULL, 'ERROR', 'SKYSCRAPERS_UTILS.START_GAME', 'Головоломка с puzzle_id=' || v_puzzle_id || ' не найдена');
				RAISE_APPLICATION_ERROR(-20999, 'Ошибка: Головоломка не найдена');
        END;
        
        v_user_id := GET_ACTIVE_USER();
        
        
        IF v_user_id = -1 THEN
            INSERT INTO USERS (ID, USER_ID, USERNAME, GAMES_COUNT)
            VALUES (USERS_SEQ.NEXTVAL, UID, SYS_CONTEXT('USERENV', 'SESSION_USER'), 0);
            v_user_id := USERS_SEQ.CURRVAL;
        END IF;
        
        SELECT ID INTO v_status_id FROM GAME_STATUSES WHERE NAME = 'Активна';
        
      
        INSERT INTO GAME_SESSIONS (ID, USER_ID, PUZZLE_ID, STATUS_ID, START_TIME, STEPS_COUNT)
        VALUES (GAME_SESSIONS_SEQ.NEXTVAL, v_user_id, v_puzzle_id, v_status_id, SYSDATE, 0);
        
        v_game_session_id := GAME_SESSIONS_SEQ.CURRVAL;
        
        SAVE_LOG(v_game_session_id, 'INFO', 'SKYSCRAPERS_UTILS.START_GAME', 'Начата новая игра. Puzzle_ID: ' || v_puzzle_id || ', Session_ID: ' || v_game_session_id);
        
        
        DBMS_OUTPUT.PUT_LINE('Игра начата! Session ID: ' || v_game_session_id);
        DRAW_PLAYING_FIELD(v_puzzle_id, v_game_session_id);
        
        DBMS_OUTPUT.PUT_LINE(' ');
        GET_MOVE_PROMT;
        
        SKYSCRAPERS_UTILS.SHOW_AVAILABLE_ACTIONS();
        CRLF;
        
    EXCEPTION
        WHEN OTHERS THEN
        	IF SQLCODE = -20999 THEN
        		RAISE;
    		ELSE
	            SAVE_LOG(v_game_session_id, 'ERROR', 'SKYSCRAPERS_UTILS.START_GAME', 'Ошибка при запуске игры для puzzle_id=' || v_puzzle_id || '. SQLERRM: ' || SQLERRM);
				RAISE_APPLICATION_ERROR(-20999, 'Ошибка при запуске игры.');
    		END IF;
    END START_GAME;
    ----------------------------------------------------------
    
   
   
    
	----------------------------------------------------------
	PROCEDURE END_GAME(v_game_status_id IN NUMBER) IS
		v_game_session_id NUMBER;
		v_status_exists NUMBER;
		v_status_name VARCHAR2(200);
		v_start_time DATE;
		v_duration_str VARCHAR2(100);
	BEGIN
		v_game_session_id := GET_ACTIVE_SESSION_ID(GET_ACTIVE_USER());
		IF v_game_session_id = -1 THEN
			SAVE_LOG(NULL, 'ERROR', 'SKYSCRAPERS_UTILS.END_GAME', 'Ошибка при завершении игры. session_id не найден');
			RAISE_APPLICATION_ERROR(-20999, 'Ошибка при завершении игры.');
		END IF;
		
		BEGIN
			SELECT NAME INTO v_status_name
			FROM GAME_STATUSES 
			WHERE ID = v_game_status_id;
		EXCEPTION
			WHEN NO_DATA_FOUND THEN
				SAVE_LOG(v_game_session_id, 'ERROR', 'SKYSCRAPERS_UTILS.END_GAME', 'Неверный статус игры: ' || v_game_status_id);
				RAISE_APPLICATION_ERROR(-20999, 'Ошибка при завершении игры.');
		END;
		
		-- Получаем время начала игры
		SELECT START_TIME INTO v_start_time
		FROM GAME_SESSIONS
		WHERE ID = v_game_session_id;
		
		-- Рассчитываем продолжительность игры
		v_duration_str := FORMAT_GAME_DURATION(v_start_time, SYSDATE);
		
		UPDATE GAME_SESSIONS 
		SET STATUS_ID = v_game_status_id,
			END_TIME = SYSDATE
		WHERE ID = v_game_session_id;
		
		SAVE_LOG(v_game_session_id, 'INFO', 'SKYSCRAPERS_UTILS.END_GAME', 
			'Игра завершена. Session_ID: ' || v_game_session_id || 
			', Статус: ' || v_status_name || 
			', Длительность: ' || v_duration_str);
		
		DBMS_OUTPUT.PUT_LINE('Игра завершена. Session ID: ' || v_game_session_id || 
			', Статус: ' || v_status_name || 
			', Время игры: ' || v_duration_str);
		CRLF;
		
	EXCEPTION
		WHEN OTHERS THEN
			IF SQLCODE = -20999 THEN
				RAISE;
			ELSE
				SAVE_LOG(v_game_session_id, 'ERROR', 'SKYSCRAPERS_UTILS.END_GAME', 
					'Ошибка при завершении игры. Session_ID: ' || v_game_session_id || 
					', SQLERRM: ' || SQLERRM);
				RAISE_APPLICATION_ERROR(-20999, 'Ошибка при завершении игры.');
			END IF;
	END END_GAME;
	----------------------------------------------------------
    




        ----------------------------------------------------------
	FUNCTION GET_ACTIVE_USER RETURN NUMBER IS
    	v_user_id NUMBER;
    	v_username VARCHAR2(500);
	BEGIN
		
    	SELECT ID INTO v_user_id
    	FROM USERS 
    	WHERE USER_ID = UID;
    
    	RETURN v_user_id;
    
	EXCEPTION
    	WHEN NO_DATA_FOUND THEN
        	RETURN -1; 
    	WHEN OTHERS THEN
        	SKYSCRAPERS_UTILS.SAVE_LOG(NULL, 'ERROR', 'SKYSCRAPERS_UTILS.GET_ACTIVE_USER', 'Ошибка при определении пользователя. SQLERRM: ' || SQLERRM);
			RAISE_APPLICATION_ERROR(-20999, 'Неизвестная ошибка сервера.');
	END GET_ACTIVE_USER;
       ----------------------------------------------------------
    
    
    
    

	----------------------------------------------------------
        FUNCTION GET_ACTIVE_SESSION_ID(v_user_id IN NUMBER) RETURN NUMBER IS
    	v_game_session_id NUMBER;
	BEGIN
    
    	SELECT ID INTO v_game_session_id
    	FROM GAME_SESSIONS 
    	WHERE USER_ID = v_user_id 
    	AND STATUS_ID = 1
    	AND ROWNUM = 1;
    
    	RETURN v_game_session_id;
    
	EXCEPTION
    	WHEN NO_DATA_FOUND THEN
        	RETURN -1;  -- Активная сессия не найдена
    	WHEN OTHERS THEN
        	SKYSCRAPERS_UTILS.SAVE_LOG(NULL, 'ERROR', 'SKYSCRAPERS_UTILS.GET_ACTIVE_SESSION_ID', 'Ошибка при определении активнйо игрвой сессии. SQLERRM: ' || SQLERRM);
			RAISE_APPLICATION_ERROR(-20999, 'Неизвестная ошибка сервера.');
	END GET_ACTIVE_SESSION_ID;
        ----------------------------------------------------------

    


    
    ----------------------------------------------------------
   PROCEDURE DRAW_PLAYING_FIELD(
        v_puzzle_id IN NUMBER,
        v_game_session_id IN NUMBER DEFAULT NULL
    ) IS
        v_size NUMBER;
        v_top_clues SYS.ODCINUMBERLIST;
        v_right_clues SYS.ODCINUMBERLIST;
        v_bottom_clues SYS.ODCINUMBERLIST;
        v_left_clues SYS.ODCINUMBERLIST;
        v_cells DBMS_SQL.NUMBER_TABLE;
        v_marks DBMS_SQL.NUMBER_TABLE;
        v_current_step_number NUMBER;
    BEGIN
        SELECT dl.SIZE_NUMBER INTO v_size
        FROM PUZZLES p
        JOIN DIFFICULTY_LEVELS dl ON p.DIFFICULTY_LEVEL_ID = dl.ID
        WHERE p.ID = v_puzzle_id;
        
        -- Получаем подсказки
        SELECT VALUE BULK COLLECT INTO v_top_clues
        FROM CLUES WHERE PUZZLE_ID = v_puzzle_id AND SIDE = 'TOP' ORDER BY CLUE_POSITION;
        
        SELECT VALUE BULK COLLECT INTO v_right_clues
        FROM CLUES WHERE PUZZLE_ID = v_puzzle_id AND SIDE = 'RIGHT' ORDER BY CLUE_POSITION;
        
        SELECT VALUE BULK COLLECT INTO v_bottom_clues
        FROM CLUES WHERE PUZZLE_ID = v_puzzle_id AND SIDE = 'BOTTOM' ORDER BY CLUE_POSITION;
        
        SELECT VALUE BULK COLLECT INTO v_left_clues
        FROM CLUES WHERE PUZZLE_ID = v_puzzle_id AND SIDE = 'LEFT' ORDER BY CLUE_POSITION;
        
        -- Инициализируем массивы
        FOR i IN 1..v_size LOOP
            FOR j IN 1..v_size LOOP
                v_cells((i-1)*v_size + j) := 0;
                v_marks((i-1)*v_size + j) := 0;
            END LOOP;
        END LOOP;
        
        -- Если передан v_game_session_id, получаем заполненные клетки и пометки
        IF v_game_session_id IS NOT NULL THEN
            -- Получаем номер текущего актуального шага
            BEGIN
                SELECT STEP_NUMBER INTO v_current_step_number
                FROM GAME_STEPS
                WHERE SESSION_ID = v_game_session_id
                AND IS_ACTUAL = 1;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    v_current_step_number := 0; -- Если нет актуальных шагов
            END;

            -- Берем для каждой клетки последний ход, который был ДО или РАВЕН текущему шагу
            FOR rec IN (
                SELECT x, y, value, is_mark
				FROM (
				    SELECT 
				        gs.COORDINATE_X as x,
				        gs.COORDINATE_Y as y, 
				        gs.VALUE as value,
				        gs.IS_MARK as is_mark,
				        ROW_NUMBER() OVER (
				            PARTITION BY gs.COORDINATE_X, gs.COORDINATE_Y 
				            ORDER BY gs.STEP_NUMBER DESC
				        ) as rn
				    FROM GAME_STEPS gs
				    WHERE gs.SESSION_ID = v_game_session_id 
				    -- Включаем все ходы, включая очистки (значение 0)
				    AND gs.STEP_NUMBER <= v_current_step_number
				)
				WHERE rn = 1
				-- Исключаем клетки, которые были очищены (значение 0 для обычных ходов)
				AND (is_mark = 1 OR (is_mark = 0 AND value > 0))
            ) LOOP
                IF rec.is_mark = 1 THEN
                    v_marks((rec.y-1)*v_size + rec.x) := rec.value;
                ELSE
                    v_cells((rec.y-1)*v_size + rec.x) := rec.value;
                END IF;
            END LOOP;
        END IF;
        
        -- ВНЕШНЯЯ РАМКА: Координаты X (СВЕРХУ)
        DBMS_OUTPUT.PUT('         '); -- Отступ для Y координаты и левой подсказки
        FOR i IN 1..v_size LOOP
            DBMS_OUTPUT.PUT(' ' || i || ' ');
        END LOOP;
        DBMS_OUTPUT.PUT_LINE('');
        
        -- Горизонтальный разделитель для координаты
        DBMS_OUTPUT.PUT('         ');
        FOR i IN 1..v_size LOOP
            DBMS_OUTPUT.PUT('---');
        END LOOP;
        DBMS_OUTPUT.PUT_LINE('');
        
        -- Верхние подсказки
        DBMS_OUTPUT.PUT('         ');
        FOR i IN 1..v_size LOOP
            DBMS_OUTPUT.PUT(' ' || v_top_clues(i) || ' ');
        END LOOP;
       	DBMS_OUTPUT.PUT_LINE('');
		-- DBMS_OUTPUT.PUT_LINE('  |');
        
        -- Внутренний разделитель
        DBMS_OUTPUT.PUT('         ');
        FOR i IN 1..v_size LOOP
            DBMS_OUTPUT.PUT('---');
        END LOOP;
        DBMS_OUTPUT.PUT_LINE('');
        
        -- Основное поле и боковые подсказки/координаты
        FOR i IN 1..v_size LOOP
            -- ВНЕШНЯЯ РАМКА: Выводим координату Y
            DBMS_OUTPUT.PUT(' ' || RPAD(i, 2) || ' |'); 
            
            -- Выводим левую подсказку
            DBMS_OUTPUT.PUT(' ' || v_left_clues(i) || ' |');
            
            -- Выводим ячейки поля
            FOR j IN 1..v_size LOOP
                IF v_cells((i-1)*v_size + j) > 0 THEN
                    -- Обычный ход
                    DBMS_OUTPUT.PUT(' ' || v_cells((i-1)*v_size + j) || ' ');
                ELSIF v_marks((i-1)*v_size + j) > 0 THEN
                    -- Пометка карандашом (используем скобки для выделения пометки)
                    DBMS_OUTPUT.PUT('(' || v_marks((i-1)*v_size + j) || ')');
                ELSE
                    -- Пустая клетка
                    DBMS_OUTPUT.PUT(' # ');
                END IF;
            END LOOP;
            
            -- Выводим правую подсказку (ВНЕШНЯЯ КООРДИНАТА Y УДАЛЕНА)
            DBMS_OUTPUT.PUT_LINE('| ' || v_right_clues(i));
        END LOOP;
        
        -- Внутренний разделитель
        DBMS_OUTPUT.PUT('         ');
        FOR i IN 1..v_size LOOP
            DBMS_OUTPUT.PUT('---');
        END LOOP;
        DBMS_OUTPUT.PUT_LINE('');
        
        -- Нижние подсказки
        DBMS_OUTPUT.PUT('         ');
        FOR i IN 1..v_size LOOP
            DBMS_OUTPUT.PUT(' ' || v_bottom_clues(i) || ' ');
        END LOOP;
        
        CRLF; 
        
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            SAVE_LOG(v_game_session_id, 'ERROR', 'DRAW_PLAYING_FIELD', 'Головоломка с ID ' || v_puzzle_id || ' не найдена. SQLERRM: ' || SQLERRM);
            RAISE_APPLICATION_ERROR(-20999, 'Ошибка: Головоломка не найдена');
        WHEN OTHERS THEN
            SAVE_LOG(v_game_session_id, 'ERROR', 'DRAW_PLAYING_FIELD', 'Ошибка при отрисовке поля для v_puzzle_id=' || v_puzzle_id || '. SQLERRM: ' || SQLERRM);
            RAISE_APPLICATION_ERROR(-20999, 'Ошибка при отрисовке поля');

    END DRAW_PLAYING_FIELD;

    ----------------------------------------------------------
    
    
    
    

    ----------------------------------------------------------
    PROCEDURE SAVE_LOG(
        v_game_session_id IN NUMBER,
        v_log_type IN VARCHAR2,
        v_procedure_name IN VARCHAR2,
        v_message IN VARCHAR2
    ) IS
    BEGIN
        INSERT INTO LOGS (ID, SESSION_ID, LOG_TYPE, PROCEDURE_NAME, MESSAGE, LOG_DATE)
        VALUES (LOGS_SEQ.NEXTVAL, v_game_session_id, v_log_type, v_procedure_name, v_message, SYSDATE);
    EXCEPTION
    	WHEN OTHERS THEN
    		NULL;
    END SAVE_LOG;
	----------------------------------------------------------
    
    
    
    
    
    ----------------------------------------------------------
    PROCEDURE GET_GAME_CATALOG IS
	BEGIN
	    DBMS_OUTPUT.PUT_LINE('=== КАТАЛОГ ГОЛОВОЛОМОК ===');
	    DBMS_OUTPUT.PUT_LINE('');
	    
	    FOR v_puzzle_rec IN (
	        SELECT p.ID, p.SEED, dl.DIFFICULTY_NAME, dl.SIZE_NUMBER
	        FROM PUZZLES p
	        JOIN DIFFICULTY_LEVELS dl ON p.DIFFICULTY_LEVEL_ID = dl.ID
	        ORDER BY dl.SIZE_NUMBER, p.ID
	    ) LOOP
	        -- НАЧАЛО: Блок EXCEPTION для обработки ошибок отрисовки
	        BEGIN
	            DBMS_OUTPUT.PUT_LINE('Головоломка (Seed: ' || v_puzzle_rec.SEED || ')');
	            DBMS_OUTPUT.PUT_LINE('Сложность: ' || v_puzzle_rec.DIFFICULTY_NAME || ' (' || v_puzzle_rec.SIZE_NUMBER || 'x' || v_puzzle_rec.SIZE_NUMBER || ')');
	            DBMS_OUTPUT.PUT_LINE('');
	            
	            -- Вызов DRAW_PLAYING_FIELD (здесь может произойти ORA-06533)
	            DRAW_PLAYING_FIELD(v_puzzle_rec.ID);
	            
	        EXCEPTION
	            WHEN OTHERS THEN
	                -- Логируем ошибку для данной конкретной головоломки
	                SAVE_LOG(NULL, 'WARNING', 'SKYSCRAPERS_UTILS.GET_GAME_CATALOG', 
	                         'Ошибка отрисовки пазла ID=' || v_puzzle_rec.ID || '. SQLERRM: ' || SQLERRM);
	                
	                -- Выводим сообщение об ошибке пользователю, но продолжаем цикл
	                DBMS_OUTPUT.PUT_LINE('--- ОШИБКА: Неполные данные для отрисовки (' || SQLERRM || ') ---');
	                DBMS_OUTPUT.PUT_LINE('-----------------------------------------------------------');
	                CRLF; 
	        END;
	        -- КОНЕЦ: Блок EXCEPTION для обработки ошибок отрисовки
	        
	    END LOOP;
	    
	    DBMS_OUTPUT.PUT_LINE('Для выбора игры используйте: SKYSCRAPERS.SELECT_GAME_FROM_CATALOG(seed);');
	    CRLF;
	    
	EXCEPTION
	    WHEN OTHERS THEN
	        IF SQLCODE = -20999 THEN
	            RAISE;
	        ELSE
	            SAVE_LOG(NULL, 'ERROR', 'SKYSCRAPERS_UTILS.GET_GAME_CATALOG', 'Ошибка при выводе каталога. SQLERRM: ' || SQLERRM);
	            RAISE_APPLICATION_ERROR(-20999, 'Ошибка при выводе каталога.');
	        END IF;
	END GET_GAME_CATALOG;
    ----------------------------------------------------------
    
    
    
    ----------------------------------------------------------
    FUNCTION CHECK_WIN(v_game_session_id IN NUMBER, v_puzzle_id IN NUMBER) RETURN NUMBER IS
        v_match_count NUMBER;
        v_total_cells NUMBER;
    BEGIN
        -- Проверяем, что все клетки заполнены и соответствуют решению
        SELECT COUNT(*) INTO v_match_count
        FROM (
            -- Берем последний ход для каждой клетки (без пометок)
            SELECT 
                gs.COORDINATE_X, 
                gs.COORDINATE_Y, 
                gs.VALUE
            FROM GAME_STEPS gs
            WHERE gs.SESSION_ID = v_game_session_id 
            AND gs.IS_MARK = 0
            AND gs.STEP_NUMBER = (
    			SELECT MAX(gs2.STEP_NUMBER)
    			FROM GAME_STEPS gs2
    			WHERE gs2.SESSION_ID = gs.SESSION_ID
    			AND gs2.COORDINATE_X = gs.COORDINATE_X
    			AND gs2.COORDINATE_Y = gs.COORDINATE_Y
    			AND gs2.IS_MARK = 0
			)
            -- Исключаем клетки, которые были очищены
            AND gs.VALUE IS NOT NULL
            AND gs.VALUE > 0
        ) player_moves
        JOIN (
            -- Выигрышная комбинация
            SELECT COORDINATE_X, COORDINATE_Y, VALUE
            FROM SOLUTIONS
            WHERE PUZZLE_ID = v_puzzle_id
        ) solution
        ON player_moves.COORDINATE_X = solution.COORDINATE_X
        AND player_moves.COORDINATE_Y = solution.COORDINATE_Y
        AND player_moves.VALUE = solution.VALUE;
        
        -- Получаем общее количество клеток в головоломке
        SELECT COUNT(*) INTO v_total_cells
        FROM SOLUTIONS
        WHERE PUZZLE_ID = v_puzzle_id;
        
        -- Если все клетки совпадают с решением - победа
        IF v_match_count = v_total_cells THEN
            RETURN 1;
        ELSE
            RETURN 0;
        END IF;
        
    EXCEPTION
        WHEN OTHERS THEN
            SAVE_LOG(v_game_session_id, 'ERROR', 'SKYSCRAPERS_UTILS.CHECK_WIN', 'SQLERRM: ' || SQLERRM);
    		RAISE_APPLICATION_ERROR(-20999, 'Внутренняя ошибка сервера.');
    END CHECK_WIN;
    ----------------------------------------------------------
    
    
    
    
    ----------------------------------------------------------
    PROCEDURE GET_MOVE_PROMT IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE('=== КАК СОВЕРШИТЬ ХОД ===');
        DBMS_OUTPUT.PUT_LINE(' ');
        DBMS_OUTPUT.PUT_LINE('SKYSCRAPERS.SET_SKYSCRAPER(x, y, значение, пометка);');
        DBMS_OUTPUT.PUT_LINE(' ');
        DBMS_OUTPUT.PUT_LINE('x, y - координаты клетки (1..N)');
        DBMS_OUTPUT.PUT_LINE('значение - высота небоскрёба (1..N) или 0 для очистки клетки от хода');
        DBMS_OUTPUT.PUT_LINE('пометка - 0 (ход) или 1 (пометка карандашом)');
        DBMS_OUTPUT.PUT_LINE(' ');
    	DBMS_OUTPUT.PUT_LINE('N - размерность игрового поля');
    	DBMS_OUTPUT.PUT_LINE(' ');
        DBMS_OUTPUT.PUT_LINE('Пример: SKYSCRAPERS.SET_SKYSCRAPER(2, 3, 4, 0);');
    	CRLF;
    EXCEPTION
        WHEN OTHERS THEN
            SAVE_LOG(NULL, 'ERROR', 'SKYSCRAPERS_UTILS.GET_MOVE_PROMT', 'SQLERRM: ' || SQLERRM);
    		RAISE_APPLICATION_ERROR(-20999, 'Ошибка при получении правил совершения хода.');
    END GET_MOVE_PROMT;
    ----------------------------------------------------------

    
    
    
    ----------------------------------------------------------
    PROCEDURE VALIDATE_MOVE_PARAMS(
        v_coordinate_x IN NUMBER,
        v_coordinate_y IN NUMBER, 
        v_value IN NUMBER,
        v_is_mark IN NUMBER,
        v_field_size IN NUMBER
    ) IS
    BEGIN
        -- Проверка координат
        IF v_coordinate_x < 1 OR v_coordinate_x > v_field_size OR 
           v_coordinate_y < 1 OR v_coordinate_y > v_field_size THEN
            SAVE_LOG(NULL, 'WARNING', 'SKYSCRAPERS_UTILS.VALIDATE_MOVE_PARAMS', 'Неверные координаты: X=' || v_coordinate_x || ', Y=' || v_coordinate_y || ', field_size=' || v_field_size);
            RAISE_APPLICATION_ERROR(-20999, 'Ошибка: Координаты выходят за пределы поля ' || v_field_size || 'x' || v_field_size);
        END IF;
        
        -- Проверка значения
        IF v_value < 0 OR v_value > v_field_size THEN
            SAVE_LOG(NULL, 'WARNING', 'SKYSCRAPERS_UTILS.VALIDATE_MOVE_PARAMS', 'Неверное значение: ' || v_value || ', field_size=' || v_field_size);
            RAISE_APPLICATION_ERROR(-20999, 'Ошибка: Значение должно быть от 0 до ' || v_field_size);
        END IF;
        
        -- Проверка флага пометки
        IF v_is_mark NOT IN (0, 1) THEN
            SAVE_LOG(NULL, 'WARNING', 'SKYSCRAPERS_UTILS.VALIDATE_MOVE_PARAMS', 'Неверное значение пометки: ' || v_is_mark);
            RAISE_APPLICATION_ERROR(-20999, 'Ошибка: Флаг пометки должен быть 0 или 1');
        END IF;
    
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -20999 THEN
                RAISE;  -- Пробрасываем наши пользовательские ошибки дальше
            ELSE
                SAVE_LOG(NULL, 'ERROR', 'SKYSCRAPERS_UTILS.VALIDATE_MOVE_PARAMS', 'Непредвиденная ошибка при валидации параметров хода. X: ' || v_coordinate_x || ', Y: ' || v_coordinate_y || ', Value: ' || v_value || ', Is_mark: ' || v_is_mark || ', Field_size: ' || v_field_size || ', SQLERRM: ' || SQLERRM);
                RAISE_APPLICATION_ERROR(-20999, 'Внутренняя ошибка сервера при проверке параметров хода.');
            END IF;
    END VALIDATE_MOVE_PARAMS;
    ----------------------------------------------------------
        
        
        
        
        
    ----------------------------------------------------------
    FUNCTION GET_VISIBLE_SKYSCRAPERS(
        v_coordinate_x IN NUMBER,
        v_coordinate_y IN NUMBER, 
        v_side IN VARCHAR2,
        v_game_session_id IN NUMBER
    ) RETURN NUMBER IS
        v_field_size NUMBER;
        v_visible_count NUMBER := 0;
        v_max_height NUMBER := 0;
        v_current_height NUMBER;
        v_field_matrix DBMS_SQL.NUMBER_TABLE;
    BEGIN
        SELECT dl.SIZE_NUMBER INTO v_field_size
        FROM GAME_SESSIONS gs
        JOIN PUZZLES p ON gs.PUZZLE_ID = p.ID
        JOIN DIFFICULTY_LEVELS dl ON p.DIFFICULTY_LEVEL_ID = dl.ID
        WHERE gs.ID = v_game_session_id;
        
        -- Получаем текущее состояние поля
        v_field_matrix := GET_CURRENT_FIELD_MATRIX(v_game_session_id);
        
        -- В зависимости от стороны обходим клетки в нужном направлении
        CASE v_side
            WHEN 'TOP' THEN
                -- Смотрим сверху вниз по столбцу
                FOR i IN 1..v_field_size LOOP
                    v_current_height := v_field_matrix((i-1)*v_field_size + v_coordinate_x);
                    IF v_current_height > v_max_height THEN
                        v_visible_count := v_visible_count + 1;
                        v_max_height := v_current_height;
                    END IF;
                END LOOP;
                
            WHEN 'BOTTOM' THEN
                -- Смотрим снизу вверх по столбцу
                v_max_height := 0;
                FOR i IN REVERSE 1..v_field_size LOOP
                    v_current_height := v_field_matrix((i-1)*v_field_size + v_coordinate_x);
                    IF v_current_height > v_max_height THEN
                        v_visible_count := v_visible_count + 1;
                        v_max_height := v_current_height;
                    END IF;
                END LOOP;
                
            WHEN 'LEFT' THEN
                -- Смотрим слева направо по строке
                v_max_height := 0;
                FOR i IN 1..v_field_size LOOP
                    v_current_height := v_field_matrix((v_coordinate_y-1)*v_field_size + i);
                    IF v_current_height > v_max_height THEN
                        v_visible_count := v_visible_count + 1;
                        v_max_height := v_current_height;
                    END IF;
                END LOOP;
                
            WHEN 'RIGHT' THEN
                -- Смотрим справа налево по строке
                v_max_height := 0;
                FOR i IN REVERSE 1..v_field_size LOOP
                    v_current_height := v_field_matrix((v_coordinate_y-1)*v_field_size + i);
                    IF v_current_height > v_max_height THEN
                        v_visible_count := v_visible_count + 1;
                        v_max_height := v_current_height;
                    END IF;
                END LOOP;
                
            ELSE
                SAVE_LOG(v_game_session_id, 'ERROR', 'SKYSCRAPERS_UTILS.GET_VISIBLE_SKYSCRAPERS', 'Неизвестная сторона: ' || v_side);
                RAISE_APPLICATION_ERROR(-20999, 'Внутренняя ошибка сервера.');
        END CASE;
        
        RETURN v_visible_count;
        
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -20999 THEN
                RAISE;
            ELSE
                SAVE_LOG(v_game_session_id, 'ERROR', 'SKYSCRAPERS_UTILS.GET_VISIBLE_SKYSCRAPERS', 'Ошибка при расчете видимых небоскребов. X: ' || v_coordinate_x || ', Y: ' || v_coordinate_y || ', Side: ' || v_side || ', SQLERRM: ' || SQLERRM);
                RAISE_APPLICATION_ERROR(-20999, 'Внутренняя ошибка сервера.');
            END IF;
    END GET_VISIBLE_SKYSCRAPERS;
    ----------------------------------------------------------
    
    
    
    
    
	----------------------------------------------------------
	FUNCTION GET_CURRENT_FIELD_MATRIX(v_game_session_id IN NUMBER) 
	RETURN DBMS_SQL.NUMBER_TABLE IS
		v_field_matrix DBMS_SQL.NUMBER_TABLE;
		v_field_size NUMBER;
		v_current_step_number NUMBER;
	BEGIN
		-- Получаем размер поля
		SELECT dl.SIZE_NUMBER INTO v_field_size
		FROM GAME_SESSIONS gs
		JOIN PUZZLES p ON gs.PUZZLE_ID = p.ID  
		JOIN DIFFICULTY_LEVELS dl ON p.DIFFICULTY_LEVEL_ID = dl.ID
		WHERE gs.ID = v_game_session_id;
		
		-- Инициализируем матрицу нулями
		FOR i IN 1..v_field_size LOOP
			FOR j IN 1..v_field_size LOOP
				v_field_matrix((i-1)*v_field_size + j) := 0;
			END LOOP;
		END LOOP;
		
		-- Получаем номер текущего актуального шага
		BEGIN
			SELECT STEP_NUMBER INTO v_current_step_number
			FROM GAME_STEPS
			WHERE SESSION_ID = v_game_session_id
			AND IS_ACTUAL = 1;
		EXCEPTION
			WHEN NO_DATA_FOUND THEN
				v_current_step_number := 0;
		END;
		
		-- Заполняем значениями из последних ходов (с учетом очисток)
		FOR rec IN (
			-- Для каждой клетки находим последний ход до текущего шага
			SELECT x, y, value, is_mark
			FROM (
				SELECT 
					gs.COORDINATE_X as x,
					gs.COORDINATE_Y as y, 
					gs.VALUE as value,
					gs.IS_MARK as is_mark,
					ROW_NUMBER() OVER (PARTITION BY gs.COORDINATE_X, gs.COORDINATE_Y ORDER BY gs.STEP_NUMBER DESC) as rn
				FROM GAME_STEPS gs
				WHERE gs.SESSION_ID = v_game_session_id 
				AND gs.STEP_NUMBER <= v_current_step_number
			)
			WHERE rn = 1
			-- Исключаем клетки, которые были очищены (значение 0 для обычных ходов)
			AND (is_mark = 1 OR (is_mark = 0 AND value > 0))
		) LOOP
			IF rec.is_mark = 0 THEN -- Только обычные ходы, не пометки
				v_field_matrix((rec.y-1)*v_field_size + rec.x) := rec.value;
			END IF;
		END LOOP;
		
		RETURN v_field_matrix;
		
	EXCEPTION
		WHEN OTHERS THEN
			SAVE_LOG(v_game_session_id, 'ERROR', 'SKYSCRAPERS_UTILS.GET_CURRENT_FIELD_MATRIX', 'Ошибка при получении матрицы поля. SQLERRM: ' || SQLERRM);
			RAISE_APPLICATION_ERROR(-20999, 'Внутренняя ошибка сервера.');
	END GET_CURRENT_FIELD_MATRIX;
	----------------------------------------------------------
    
    
    
    
    ----------------------------------------------------------
    FUNCTION GET_CELL_VALUE_FROM_MATRIX(
        v_field_matrix IN DBMS_SQL.NUMBER_TABLE,
        v_field_size IN NUMBER,
        v_coordinate_x IN NUMBER,
        v_coordinate_y IN NUMBER
    ) RETURN NUMBER IS
    BEGIN
        RETURN v_field_matrix((v_coordinate_y-1)*v_field_size + v_coordinate_x);
        
    EXCEPTION
        WHEN OTHERS THEN
            SAVE_LOG(NULL, 'ERROR', 'SKYSCRAPERS_UTILS.GET_CELL_VALUE_FROM_MATRIX', 'Ошибка при получении значения из матрицы. X: ' || v_coordinate_x || ', Y: ' || v_coordinate_y || ', Field_size: ' || v_field_size || ', SQLERRM: ' || SQLERRM);
            RAISE_APPLICATION_ERROR(-20999, 'Внутренняя ошибка сервера.');
    END GET_CELL_VALUE_FROM_MATRIX;
    ----------------------------------------------------------
    
    
    
    
    
    ----------------------------------------------------------
    FUNCTION IS_VALUE_POSSIBLE_IN_MATRIX(
        v_field_matrix IN DBMS_SQL.NUMBER_TABLE,
        v_field_size IN NUMBER,
        v_coordinate_x IN NUMBER,
        v_coordinate_y IN NUMBER,
        v_value IN NUMBER
    ) RETURN BOOLEAN IS
    BEGIN
        -- Проверка строки
        FOR i IN 1..v_field_size LOOP
            IF i != v_coordinate_x AND 
               GET_CELL_VALUE_FROM_MATRIX(v_field_matrix, v_field_size, i, v_coordinate_y) = v_value THEN
                RETURN FALSE;
            END IF;
        END LOOP;
        
        -- Проверка столбца
        FOR i IN 1..v_field_size LOOP
            IF i != v_coordinate_y AND 
               GET_CELL_VALUE_FROM_MATRIX(v_field_matrix, v_field_size, v_coordinate_x, i) = v_value THEN
                RETURN FALSE;
            END IF;
        END LOOP;
        
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            SAVE_LOG(NULL, 'ERROR', 'SKYSCRAPERS_UTILS.IS_VALUE_POSSIBLE_IN_MATRIX', 'Ошибка при проверке значения в матрице. X: ' || v_coordinate_x || ', Y: ' || v_coordinate_y || ', Value: ' || v_value || ', Field_size: ' || v_field_size || ', SQLERRM: ' || SQLERRM);
            RAISE_APPLICATION_ERROR(-20999, 'Внутренняя ошибка сервера при проверке значения.');
    END IS_VALUE_POSSIBLE_IN_MATRIX;
    ----------------------------------------------------------
    
    
    
    
    
    
	----------------------------------------------------------
	PROCEDURE SHOW_GAMES_LIST(v_user_id IN NUMBER) IS
		v_total_games NUMBER := 0;
		v_wins NUMBER := 0;
		v_duration_str VARCHAR2(100);
	BEGIN
		DBMS_OUTPUT.PUT_LINE('=== ИСТОРИЯ ИГР ===');
		DBMS_OUTPUT.PUT_LINE('');
		
		-- Статистика (только завершенные игры, кроме активных)
		SELECT COUNT(*), 
			   COUNT(CASE WHEN gs.NAME = 'Победа' THEN 1 END)
		INTO v_total_games, v_wins
		FROM GAME_SESSIONS s
		JOIN GAME_STATUSES gs ON s.STATUS_ID = gs.ID
		WHERE s.USER_ID = v_user_id
		AND gs.NAME IN ('Победа', 'Завершена', 'Истекла', 'Импорт', 'Экспорт');
		
		DBMS_OUTPUT.PUT_LINE('Общая статистика:');
		DBMS_OUTPUT.PUT_LINE('Всего завершенных игр: ' || v_total_games);
		DBMS_OUTPUT.PUT_LINE('Побед: ' || v_wins);
		IF v_total_games > 0 THEN
			DBMS_OUTPUT.PUT_LINE('Процент побед: ' || ROUND((v_wins / v_total_games) * 100, 1) || '%');
		END IF;
		DBMS_OUTPUT.PUT_LINE('');
		
		-- Список игр
		DBMS_OUTPUT.PUT_LINE('Список завершенных игр:');
		DBMS_OUTPUT.PUT_LINE('----------------------------------------------------------------------------------------------------------------');
		DBMS_OUTPUT.PUT_LINE('ID     | Начало игры      | Конец игры       | Длительность     |   Статус   | Ходов | Сложность');
		DBMS_OUTPUT.PUT_LINE('----------------------------------------------------------------------------------------------------------------');
		
		FOR game_rec IN (
			SELECT 
				s.ID as session_id,
				s.START_TIME,
				s.END_TIME,
				gs.NAME as status_name,
				s.STEPS_COUNT,
				dl.DIFFICULTY_NAME,
				dl.SIZE_NUMBER
			FROM GAME_SESSIONS s
			JOIN GAME_STATUSES gs ON s.STATUS_ID = gs.ID
			JOIN PUZZLES p ON s.PUZZLE_ID = p.ID
			JOIN DIFFICULTY_LEVELS dl ON p.DIFFICULTY_LEVEL_ID = dl.ID
			WHERE s.USER_ID = v_user_id
			AND gs.NAME IN ('Победа', 'Завершена', 'Истекла', 'Импорт', 'Экспорт')
			ORDER BY s.ID DESC  -- Сначала новые игры
		) LOOP
			-- Форматируем длительность игры
			v_duration_str := FORMAT_GAME_DURATION(game_rec.START_TIME, game_rec.END_TIME);
			
			-- Сокращаем для отображения в таблице (чтобы влезло в колонку)
			IF LENGTH(v_duration_str) > 15 THEN
				v_duration_str := SUBSTR(v_duration_str, 1, 15) || '...';
			END IF;
			
			DBMS_OUTPUT.PUT_LINE(
				RPAD(game_rec.session_id, 7) || '| ' ||
				RPAD(TO_CHAR(game_rec.START_TIME, 'DD.MM.YY HH24:MI'), 17) || '| ' ||
				RPAD(TO_CHAR(game_rec.END_TIME, 'DD.MM.YY HH24:MI'), 17) || '| ' ||
				RPAD(v_duration_str, 17) || '| ' ||
				RPAD(game_rec.status_name, 11) || '| ' ||
				RPAD(game_rec.STEPS_COUNT, 6) || '| ' ||
				game_rec.DIFFICULTY_NAME || ' (' || game_rec.SIZE_NUMBER || 'x' || game_rec.SIZE_NUMBER || ')'
			);
		END LOOP;
		
		DBMS_OUTPUT.PUT_LINE('----------------------------------------------------------------------------------------------------------------');
		DBMS_OUTPUT.PUT_LINE('');
		DBMS_OUTPUT.PUT_LINE('Для просмотра реплея конкретной игры используйте:');
		DBMS_OUTPUT.PUT_LINE('SKYSCRAPERS.GET_GAME_HISTORY(game_session_id);');
		DBMS_OUTPUT.PUT_LINE('где game_session_id - ID игры из таблицы выше');
		CRLF;
		
	EXCEPTION
		WHEN OTHERS THEN
			SAVE_LOG(NULL, 'ERROR', 'SKYSCRAPERS_UTILS.SHOW_GAMES_LIST', 'Ошибка при выводе списка игр. SQLERRM: ' || SQLERRM);
			RAISE_APPLICATION_ERROR(-20999, 'Ошибка при выводе списка игр.');
	END SHOW_GAMES_LIST;
	----------------------------------------------------------
    
    
    
    
    
	----------------------------------------------------------
	PROCEDURE SHOW_GAME_REPLAY(v_game_session_id IN NUMBER, v_user_id IN NUMBER) IS
		v_game_exists NUMBER;
		v_step_counter NUMBER := 0;
		v_duration_str VARCHAR2(100);
		v_regular_moves_count NUMBER := 0;  -- Счетчик обычных ходов
		v_all_moves_count NUMBER := 0;      -- Счетчик всех ходов
	BEGIN
		BEGIN
			SELECT 1 INTO v_game_exists
			FROM GAME_SESSIONS s
			WHERE s.ID = v_game_session_id
			AND s.USER_ID = v_user_id;
		EXCEPTION
			WHEN NO_DATA_FOUND THEN
				SAVE_LOG(NULL, 'ERROR', 'SKYSCRAPERS_UTILS.SHOW_GAME_REPLAY', 'Игра с ID ' || v_game_session_id || ' не найдена или не принадлежит пользователю');
				RAISE_APPLICATION_ERROR(-20999, 'Ошибка: Игра с ID ' || v_game_session_id || ' не найдена или не принадлежит вам.');
		END;
		
		DBMS_OUTPUT.PUT_LINE('=== РЕПЛЕЙ ИГРЫ ID: ' || v_game_session_id || ' ===');
		DBMS_OUTPUT.PUT_LINE('');
		
		-- Сначала подсчитаем общее количество ходов и обычных ходов
		SELECT 
			COUNT(*) as all_moves,
			COUNT(CASE WHEN IS_MARK = 0 AND VALUE > 0 THEN 1 END) as regular_moves
		INTO v_all_moves_count, v_regular_moves_count
		FROM GAME_STEPS
		WHERE SESSION_ID = v_game_session_id;
		
		-- Информация об игре
		FOR game_info IN (
			SELECT 
				s.START_TIME,
				s.END_TIME,
				gs.NAME as status_name,
				s.STEPS_COUNT,
				dl.DIFFICULTY_NAME,
				dl.SIZE_NUMBER,
				p.SEED
			FROM GAME_SESSIONS s
			JOIN GAME_STATUSES gs ON s.STATUS_ID = gs.ID
			JOIN PUZZLES p ON s.PUZZLE_ID = p.ID
			JOIN DIFFICULTY_LEVELS dl ON p.DIFFICULTY_LEVEL_ID = dl.ID
			WHERE s.ID = v_game_session_id
		) LOOP
			-- Используем функцию для форматирования длительности
			v_duration_str := FORMAT_GAME_DURATION(game_info.START_TIME, game_info.END_TIME);
			
			DBMS_OUTPUT.PUT_LINE('Информация об игре:');
			DBMS_OUTPUT.PUT_LINE('Дата: ' || TO_CHAR(game_info.START_TIME, 'DD.MM.YYYY'));
			DBMS_OUTPUT.PUT_LINE('Время начала: ' || TO_CHAR(game_info.START_TIME, 'HH24:MI:SS'));
			DBMS_OUTPUT.PUT_LINE('Время окончания: ' || TO_CHAR(game_info.END_TIME, 'HH24:MI:SS'));
			DBMS_OUTPUT.PUT_LINE('Длительность: ' || v_duration_str);
			DBMS_OUTPUT.PUT_LINE('Статус: ' || game_info.status_name);
			DBMS_OUTPUT.PUT_LINE('Количество ходов: ' || game_info.STEPS_COUNT || ' (обычные) / ' || v_all_moves_count || ' (всего)');
			DBMS_OUTPUT.PUT_LINE('Количество пометок: ' || (v_all_moves_count - v_regular_moves_count));
			DBMS_OUTPUT.PUT_LINE('Сложность: ' || game_info.DIFFICULTY_NAME || ' (' || game_info.SIZE_NUMBER || 'x' || game_info.SIZE_NUMBER || ')');
			DBMS_OUTPUT.PUT_LINE('Seed головоломки: ' || game_info.SEED);
			DBMS_OUTPUT.PUT_LINE('');
		END LOOP;
		
		-- Ходы игры
		DBMS_OUTPUT.PUT_LINE('Ходы игры:');
		DBMS_OUTPUT.PUT_LINE('----------------------------------------------------------------------------------------------------');
		DBMS_OUTPUT.PUT_LINE('Шаг | Время     | Действие                      | Клетка      | Значение');
		DBMS_OUTPUT.PUT_LINE('----------------------------------------------------------------------------------------------------');
		
		FOR step_rec IN (
			SELECT 
				gs.STEP_NUMBER,
				TO_CHAR(gs.STEP_TIME, 'HH24:MI:SS') as step_time,
				-- Для импортированных ходов используем оригинальное действие, а не "Импорт игры"
				CASE 
					WHEN gs.IS_IMPORT = 1 THEN 
						CASE 
							WHEN (gs.IS_MARK = 1 AND gs.VALUE != 0 AND gs.VALUE IS NOT NULL) THEN 'Установка пометки'
							WHEN gs.VALUE = 0 OR gs.VALUE IS NULL THEN 'Очистка клетки'
							ELSE 'Установка небоскреба'
						END || '(импорт)'
					ELSE ga.NAME
				END as action_name,
				gs.COORDINATE_X,
				gs.COORDINATE_Y,
				gs.VALUE,
				gs.IS_MARK,
				gs.IS_IMPORT
			FROM GAME_STEPS gs
			LEFT JOIN GAME_ACTIONS ga ON gs.ACTION_ID = ga.ID
			WHERE gs.SESSION_ID = v_game_session_id
			ORDER BY gs.STEP_NUMBER
		) LOOP
			v_step_counter := v_step_counter + 1;
			
			DBMS_OUTPUT.PUT_LINE(
				RPAD(step_rec.STEP_NUMBER, 4) || '| ' ||
				RPAD(step_rec.step_time, 10) || '| ' ||
				RPAD(step_rec.action_name, 30) || '| ' ||
				RPAD('(' || step_rec.COORDINATE_X || ',' || step_rec.COORDINATE_Y || ')', 12) || '| ' ||
				TO_CHAR(step_rec.VALUE)
			);
		END LOOP;
		
		DBMS_OUTPUT.PUT_LINE('----------------------------------------------------------------------------------------------------');
		CRLF;
		
	EXCEPTION
		WHEN OTHERS THEN
			IF SQLCODE = -20999 THEN
				RAISE;
			ELSE
				SAVE_LOG(NULL, 'ERROR', 'SKYSCRAPERS_UTILS.SHOW_GAME_REPLAY', 
					'Ошибка при выводе реплея игры. Game_Session_ID: ' || v_game_session_id || 
					', Step_Counter: ' || v_step_counter || 
					', SQLERRM: ' || SQLERRM);
				RAISE_APPLICATION_ERROR(-20999, 'Ошибка при выводе реплея игры: ' || SQLERRM);
			END IF;
	END SHOW_GAME_REPLAY;
	----------------------------------------------------------
    
    
    
    
    
    ----------------------------------------------------------
    PROCEDURE CRLF IS
    BEGIN
	    DBMS_OUTPUT.PUT_LINE(' ');
		DBMS_OUTPUT.PUT_LINE(' ');
		DBMS_OUTPUT.PUT_LINE(' ');
		DBMS_OUTPUT.PUT_LINE(' ');
    END CRLF;
    ----------------------------------------------------------
   
   
   
   
    ----------------------------------------------------------
    PROCEDURE SHOW_HELP_PROMPT IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE('Для получения справочной информации воспользуйтесь процедурой:');
        DBMS_OUTPUT.PUT_LINE('SKYSCRAPERS.GET_GAME_RULES;');
    END SHOW_HELP_PROMPT;
    ----------------------------------------------------------
    
    
    
    
    ----------------------------------------------------------
    PROCEDURE CHECK_USER_ACTIVE_GAME IS
        v_status_inactive_id NUMBER;
        v_status_active_id NUMBER;
        v_timeout_minutes NUMBER := 1;
        v_count NUMBER;
    BEGIN
        SELECT ID INTO v_status_active_id FROM GAME_STATUSES WHERE NAME = 'Активна';
        SELECT ID INTO v_status_inactive_id FROM GAME_STATUSES WHERE NAME = 'Истекла';

        UPDATE GAME_SESSIONS s
        SET s.STATUS_ID = v_status_inactive_id,
            s.END_TIME = SYSDATE
        WHERE s.STATUS_ID = v_status_active_id
        AND (
            (SYSDATE - (
                SELECT COALESCE(MAX(gs.STEP_TIME), s.START_TIME)
                FROM GAME_STEPS gs
                WHERE gs.SESSION_ID = s.ID
            )) * 1440 
        ) > v_timeout_minutes;
        
        v_count := SQL%ROWCOUNT;
        
        SAVE_LOG(NULL, 'INFO', 'CHECK_USER_ACTIVE_GAME', 'Задание выполнено. Завершено сессий: ' || v_count);
        
        COMMIT;
        
    EXCEPTION
        WHEN OTHERS THEN
            SAVE_LOG(NULL, 'ERROR', 'CHECK_USER_ACTIVE_GAME', 'Ошибка: ' || SQLERRM);
            ROLLBACK;
    END CHECK_USER_ACTIVE_GAME;
    ----------------------------------------------------------
    
    
    
    
    ----------------------------------------------------------
    PROCEDURE SET_DAILY_GAME IS
        v_new_puzzle_id NUMBER;
    BEGIN
        UPDATE PUZZLES SET IS_DAILY = 0;
        
        SELECT ID INTO v_new_puzzle_id
        FROM (
            SELECT ID
            FROM PUZZLES
            ORDER BY DBMS_RANDOM.VALUE
        )
        WHERE ROWNUM = 1;
        
        UPDATE PUZZLES
        SET IS_DAILY = 1
        WHERE ID = v_new_puzzle_id;
        
        SAVE_LOG(NULL, 'INFO', 'SET_DAILY_GAME', 'Новый "Пазл дня" установлен. Puzzle ID: ' || v_new_puzzle_id);
        
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            SAVE_LOG(NULL, 'ERROR', 'SET_DAILY_GAME', 'Ошибка: ' || SQLERRM);
            ROLLBACK;
    END SET_DAILY_GAME;
    ----------------------------------------------------------
   
   
   
   
    ----------------------------------------------------------
    PROCEDURE DELETE_FUTURE_STEPS(
        v_game_session_id IN NUMBER
    ) IS
        v_current_step_number NUMBER;
    BEGIN
        -- Получаем номер текущего актуального шага ДО сброса флагов
        BEGIN
            SELECT STEP_NUMBER INTO v_current_step_number
            FROM GAME_STEPS
            WHERE SESSION_ID = v_game_session_id
            AND IS_ACTUAL = 1;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RETURN; -- Если нет актуального шага, ничего не делаем
        END;

        -- Удаляем все шаги с номером больше текущего
        DELETE FROM GAME_STEPS
        WHERE SESSION_ID = v_game_session_id
        AND STEP_NUMBER > v_current_step_number;

        SAVE_LOG(v_game_session_id, 'INFO', 'SKYSCRAPERS_UTILS.DELETE_FUTURE_STEPS', 'Удалены шаги после STEP_NUMBER=' || v_current_step_number);
       
    EXCEPTION
        WHEN OTHERS THEN
            SAVE_LOG(v_game_session_id, 'ERROR', 'SKYSCRAPERS_UTILS.DELETE_FUTURE_STEPS', 'Ошибка при удалении будущих шагов. SQLERRM: ' || SQLERRM);
    END DELETE_FUTURE_STEPS;
    ----------------------------------------------------------
   
   
   
   
   
	----------------------------------------------------------
	PROCEDURE IMPORT_GAME(v_export_data IN VARCHAR2) IS
		
		v_puzzle_id NUMBER;
		v_game_session_id NUMBER;
		v_step_action_id NUMBER;
		v_user_id NUMBER;
		v_status_active_id NUMBER;
		
		-- Используем локальный тип массива для хранения парсированных элементов
		TYPE t_data_array IS TABLE OF VARCHAR2(4000) INDEX BY BINARY_INTEGER;
		v_data_array t_data_array;
		v_data_count NUMBER;
		
		v_coord_x NUMBER;
		v_coord_y NUMBER;
		v_value NUMBER;
		v_is_mark NUMBER;
		v_step_number_val NUMBER;
		
		-- Переменные для парсинга
		v_remaining_string VARCHAR2(32767) := v_export_data;
		v_segment VARCHAR2(4000);
		v_delimiter_pos NUMBER;
		v_array_index NUMBER := 1;
		
		-- Временные переменные для парсинга хода
		v_move_string VARCHAR2(4000);
		v_comma_pos1 NUMBER;
		v_comma_pos2 NUMBER;
		v_comma_pos3 NUMBER;
		v_comma_pos4 NUMBER;
		
		v_index NUMBER;
		v_move_count NUMBER := 0;
	BEGIN
		-- 1. Проверяем, что строка не пустая
		IF v_export_data IS NULL OR LENGTH(TRIM(v_export_data)) = 0 THEN
			RAISE_APPLICATION_ERROR(-20999, 'Ошибка импорта: Передана пустая строка.');
		END IF;
		
		-- 2. РУЧНОЙ ПАРСИНГ: Разделяем строку по '|'
		LOOP
			v_delimiter_pos := INSTR(v_remaining_string, '|');
			
			IF v_delimiter_pos > 0 THEN
				v_segment := SUBSTR(v_remaining_string, 1, v_delimiter_pos - 1);
				v_remaining_string := SUBSTR(v_remaining_string, v_delimiter_pos + 1);
			ELSE
				-- Последний сегмент
				v_segment := v_remaining_string;
				v_remaining_string := NULL;
			END IF;
			
			v_data_array(v_array_index) := TRIM(v_segment);
			v_array_index := v_array_index + 1;
			
			IF v_array_index > 1000 THEN 
				RAISE_APPLICATION_ERROR(-20999, 'Слишком много элементов для импорта.');
			END IF;
			
			EXIT WHEN v_remaining_string IS NULL;
		END LOOP;
		
		v_data_count := v_array_index - 1;
	
		IF v_data_count < 1 THEN
			RAISE_APPLICATION_ERROR(-20999, 'Ошибка импорта: Неверный формат данных.');
		END IF;
	
		-- 3. Обработка данных - получаем puzzle_id
		BEGIN
			v_puzzle_id := TO_NUMBER(TRIM(v_data_array(1)));
		EXCEPTION
			WHEN VALUE_ERROR THEN
				RAISE_APPLICATION_ERROR(-20999, 'Ошибка импорта: Неверный формат Puzzle ID (VALUE_ERROR).');
			WHEN INVALID_NUMBER THEN
				RAISE_APPLICATION_ERROR(-20999, 'Ошибка импорта: Неверный формат Puzzle ID (INVALID_NUMBER).');
		END;
		
		-- Проверяем существование пазла
		DECLARE
			v_puzzle_exists NUMBER;
		BEGIN
			SELECT COUNT(*) INTO v_puzzle_exists
			FROM PUZZLES
			WHERE ID = v_puzzle_id;
			
			IF v_puzzle_exists = 0 THEN
				RAISE_APPLICATION_ERROR(-20999, 'Ошибка импорта: Пазл с ID ' || v_puzzle_id || ' не найден.');
			END IF;
		END;
		
		-- Получаем ID статуса "Активна"
		SELECT ID INTO v_status_active_id FROM GAME_STATUSES WHERE NAME = 'Активна';
		
		-- Создаем новую игровую сессию
		v_user_id := GET_ACTIVE_USER();
		IF v_user_id = -1 THEN
			INSERT INTO USERS (ID, USER_ID, USERNAME, GAMES_COUNT)
			VALUES (USERS_SEQ.NEXTVAL, UID, SYS_CONTEXT('USERENV', 'SESSION_USER'), 0);
			v_user_id := USERS_SEQ.CURRVAL;
		END IF;
		
		INSERT INTO GAME_SESSIONS (ID, USER_ID, PUZZLE_ID, STATUS_ID, START_TIME, STEPS_COUNT)
		VALUES (GAME_SESSIONS_SEQ.NEXTVAL, v_user_id, v_puzzle_id, v_status_active_id, SYSDATE, 0);
		
		v_game_session_id := GAME_SESSIONS_SEQ.CURRVAL;
		
		-- Получаем ID действия "Импорт игры"
		BEGIN
			IF v_is_mark = 1 THEN
				SELECT ID INTO v_step_action_id FROM GAME_ACTIONS WHERE NAME = 'Установка пометки';
			ELSIF v_value = 0 THEN
				SELECT ID INTO v_step_action_id FROM GAME_ACTIONS WHERE NAME = 'Очистка клетки';
			ELSE
				SELECT ID INTO v_step_action_id FROM GAME_ACTIONS WHERE NAME = 'Установка небоскреба';
			END IF;
		EXCEPTION
			WHEN NO_DATA_FOUND THEN
				RAISE_APPLICATION_ERROR(-20999, 'Ошибка импорта: Действие "Импорт игры" не найдено.');
		END;
		
		-- 4. Цикл для вставки ходов (начиная с индекса 2)
		v_index := 2;  -- Инициализируем
		WHILE v_index <= v_data_count LOOP
			-- Каждый ход в формате: "1,2,2,1,1"
			v_move_string := v_data_array(v_index);
			
			-- Парсим строку хода
			BEGIN
				-- Первая запятая: координата X
				v_comma_pos1 := INSTR(v_move_string, ',');
				IF v_comma_pos1 = 0 THEN
					RAISE_APPLICATION_ERROR(-20999, 'Ошибка импорта: Неверный формат хода (отсутствует координата X). Ход: ' || v_move_string);
				END IF;
				v_coord_x := TO_NUMBER(TRIM(SUBSTR(v_move_string, 1, v_comma_pos1 - 1)));
				
				-- Вторая запятая: координата Y
				v_comma_pos2 := INSTR(v_move_string, ',', v_comma_pos1 + 1);
				IF v_comma_pos2 = 0 THEN
					RAISE_APPLICATION_ERROR(-20999, 'Ошибка импорта: Неверный формат хода (отсутствует координата Y). Ход: ' || v_move_string);
				END IF;
				v_coord_y := TO_NUMBER(TRIM(SUBSTR(v_move_string, v_comma_pos1 + 1, v_comma_pos2 - v_comma_pos1 - 1)));
				
				-- Третья запятая: значение
				v_comma_pos3 := INSTR(v_move_string, ',', v_comma_pos2 + 1);
				IF v_comma_pos3 = 0 THEN
					RAISE_APPLICATION_ERROR(-20999, 'Ошибка импорта: Неверный формат хода (отсутствует значение). Ход: ' || v_move_string);
				END IF;
				v_value := TO_NUMBER(TRIM(SUBSTR(v_move_string, v_comma_pos2 + 1, v_comma_pos3 - v_comma_pos2 - 1)));
				
				-- Четвертая запятая: флаг пометки
				v_comma_pos4 := INSTR(v_move_string, ',', v_comma_pos3 + 1);
				IF v_comma_pos4 = 0 THEN
					RAISE_APPLICATION_ERROR(-20999, 'Ошибка импорта: Неверный формат хода (отсутствует флаг пометки). Ход: ' || v_move_string);
				END IF;
				v_is_mark := TO_NUMBER(TRIM(SUBSTR(v_move_string, v_comma_pos3 + 1, v_comma_pos4 - v_comma_pos3 - 1)));
				
				-- После четвертой запятой: номер шага
				v_step_number_val := TO_NUMBER(TRIM(SUBSTR(v_move_string, v_comma_pos4 + 1)));
				
			EXCEPTION
				WHEN VALUE_ERROR THEN
					RAISE_APPLICATION_ERROR(-20999, 'Ошибка импорта: Неверный числовой формат хода: ' || v_move_string || ' (VALUE_ERROR)');
				WHEN INVALID_NUMBER THEN
					RAISE_APPLICATION_ERROR(-20999, 'Ошибка импорта: Неверный числовой формат хода: ' || v_move_string || ' (INVALID_NUMBER)');
			END;
	
			-- Вставляем ход в GAME_STEPS
			INSERT INTO GAME_STEPS (
				ID, SESSION_ID, ACTION_ID, COORDINATE_X, COORDINATE_Y, 
				VALUE, IS_ACTUAL, STEP_TIME, IS_MARK, IS_IMPORT, STEP_NUMBER
			) VALUES (
				GAME_STEPS_SEQ.NEXTVAL, v_game_session_id, 
				v_step_action_id, v_coord_x, v_coord_y, 
				v_value, 
				0, SYSDATE,  -- Импортированные шаги не активны по умолчанию
				v_is_mark, 
				1, 
				v_step_number_val
			);
			
			v_index := v_index + 1; -- Переходим к следующему ходу
		END LOOP;
		
		-- 5. Финальные обновления
		-- Устанавливаем последний ход как актуальный
		UPDATE GAME_STEPS
		SET IS_ACTUAL = 1
		WHERE SESSION_ID = v_game_session_id
		AND STEP_NUMBER = (
			SELECT MAX(STEP_NUMBER)
			FROM GAME_STEPS
			WHERE SESSION_ID = v_game_session_id
		);
		
		-- Обновляем счетчик ходов (только обычные ходы, не пометки)
		UPDATE GAME_SESSIONS
		SET STEPS_COUNT = (
			SELECT COUNT(*) 
			FROM GAME_STEPS 
			WHERE SESSION_ID = v_game_session_id 
			AND IS_MARK = 0 
			AND VALUE > 0
		)
		WHERE ID = v_game_session_id;
		
		-- Подсчитываем количество ходов
		v_move_count := v_data_count - 1;
	
		COMMIT;
		
		SAVE_LOG(v_game_session_id, 'INFO', 'SKYSCRAPERS_UTILS.IMPORT_GAME', 'Импорт завершен. Ходов восстановлено: ' || v_move_count);
		
		DRAW_PLAYING_FIELD(v_puzzle_id, v_game_session_id);
	
		DBMS_OUTPUT.PUT_LINE('=== ИМПОРТ ЗАВЕРШЕН ===');
		DBMS_OUTPUT.PUT_LINE('Игра успешно импортирована!');
		DBMS_OUTPUT.PUT_LINE('Восстановлено ходов: ' || v_move_count);
		DBMS_OUTPUT.PUT_LINE('Session ID: ' || v_game_session_id);
		DBMS_OUTPUT.PUT_LINE('Статус: Активна');
		
		-- Показываем доступные действия
		DBMS_OUTPUT.PUT_LINE('');
		SHOW_AVAILABLE_ACTIONS();
		SKYSCRAPERS_UTILS.CRLF;
		
	EXCEPTION
		WHEN OTHERS THEN
			ROLLBACK;
			SAVE_LOG(NULL, 'ERROR', 'SKYSCRAPERS_UTILS.IMPORT_GAME', 'Ошибка при импорте игры. Данные: ' || SUBSTR(v_export_data, 1, 200) || '..., SQLERRM: ' || SQLERRM);
			RAISE_APPLICATION_ERROR(-20999, 'Ошибка при импорте игры: ' || SQLERRM);
	END IMPORT_GAME;
	----------------------------------------------------------




	----------------------------------------------------------
	FUNCTION CALCULATE_SCORE(
	    v_size_number IN NUMBER,
	    v_duration_minutes IN NUMBER,
	    v_status_name IN VARCHAR2
	) RETURN NUMBER IS
	    v_score NUMBER := 0;
	    v_uppercase_status VARCHAR2(200) := UPPER(v_status_name);
	BEGIN
	    -- Проверка статуса (только победа)
	    IF v_uppercase_status != 'ПОБЕДА' THEN
	        RETURN 0;
	    END IF;
	
	    -- Ищем самый высокий балл, за который игрок квалифицировался.
	    BEGIN
	        SELECT SCORE INTO v_score
	        FROM (
	            SELECT SCORE
	            FROM SCORING_RULES
	            WHERE SIZE_NUMBER = v_size_number
	            -- Ключевая проверка: Сравнение числовых типов
	            AND v_duration_minutes <= MAX_MINUTES 
	            ORDER BY SCORE DESC 
	        )
	        WHERE ROWNUM = 1;
	        
	    EXCEPTION
	        WHEN NO_DATA_FOUND THEN
	            -- NO_DATA_FOUND указывает, что игрок не уложился ни в один лимит (даже в 9999). 
	            -- Это возможно только если размер сетки не найден в SCORING_RULES.
	            SKYSCRAPERS_UTILS.SAVE_LOG(NULL, 'WARNING', 'CALCULATE_SCORE', 
	                                       'Правила для размера ' || v_size_number || ' не найдены.');
	            v_score := 0; 
	        WHEN OTHERS THEN
	            SKYSCRAPERS_UTILS.SAVE_LOG(NULL, 'ERROR', 'CALCULATE_SCORE', 
	                                       'Критическая ошибка SQL. SQLERRM: ' || SQLERRM);
	            v_score := 0;
	    END;
	
	    RETURN v_score;
	END CALCULATE_SCORE;
	----------------------------------------------------------




	----------------------------------------------------------
	PROCEDURE SHOW_AVAILABLE_ACTIONS IS
	BEGIN
		DBMS_OUTPUT.PUT_LINE('=== ДОСТУПНЫЕ ДЕЙСТВИЯ ===');
		DBMS_OUTPUT.PUT_LINE('1. Следующий ход: SKYSCRAPERS.SET_SKYSCRAPER(x, y, значение, пометка);');
		DBMS_OUTPUT.PUT_LINE('   Пример: SKYSCRAPERS.SET_SKYSCRAPER(2, 3, 4, 0);');
		DBMS_OUTPUT.PUT_LINE(' ');
		DBMS_OUTPUT.PUT_LINE('2. Дополнительные возможности:');
		DBMS_OUTPUT.PUT_LINE('   - Отмена хода: SKYSCRAPERS.UNDO;');
		DBMS_OUTPUT.PUT_LINE('   - Возврат хода: SKYSCRAPERS.REDO;');
		DBMS_OUTPUT.PUT_LINE('   - Проверка поля: SKYSCRAPERS.CHECK_PLAYING_FIELD_STATE;');
		DBMS_OUTPUT.PUT_LINE('   - Кандидаты для клетки: SKYSCRAPERS.GET_CELL_CANDIDATES(x, y);');
		DBMS_OUTPUT.PUT_LINE('   - Правила игры: SKYSCRAPERS.GET_GAME_RULES;');
		DBMS_OUTPUT.PUT_LINE(' ');
		DBMS_OUTPUT.PUT_LINE('3. Завершение игры:');
		DBMS_OUTPUT.PUT_LINE('   - Игра автоматически завершится при победе');
		DBMS_OUTPUT.PUT_LINE('   - Есть возможность экспортировать игру, вызвав процедуру SKYSCRAPERS.EXPORT_GAME;');
		DBMS_OUTPUT.PUT_LINE('   - Есть возможность досрочно завершить игру, вызвав процедуру SKYSCRAPERS.GAME_OVER;');
		DBMS_OUTPUT.PUT_LINE('   - После 15 минут бездействия, игра завершается автоматически');
		DBMS_OUTPUT.PUT_LINE(' ');
		DBMS_OUTPUT.PUT_LINE('Для продолжения введите следующий ход...');
	END SHOW_AVAILABLE_ACTIONS;
	----------------------------------------------------------




	----------------------------------------------------------
	FUNCTION FORMAT_GAME_DURATION(v_start_time IN DATE, v_end_time IN DATE DEFAULT SYSDATE) RETURN VARCHAR2 IS
		v_duration_days NUMBER;
		v_duration_hours NUMBER;
		v_duration_minutes NUMBER;
		v_duration_seconds NUMBER;
		v_total_seconds NUMBER;
		v_time_str VARCHAR2(100);
	BEGIN
		-- Рассчитываем общее время в секундах
		v_total_seconds := ROUND((v_end_time - v_start_time) * 24 * 60 * 60);
		
		-- Разбиваем на дни, часы, минуты, секунды
		v_duration_days := TRUNC(v_total_seconds / (24 * 60 * 60));
		v_total_seconds := v_total_seconds - (v_duration_days * 24 * 60 * 60);
		
		v_duration_hours := TRUNC(v_total_seconds / (60 * 60));
		v_total_seconds := v_total_seconds - (v_duration_hours * 60 * 60);
		
		v_duration_minutes := TRUNC(v_total_seconds / 60);
		v_duration_seconds := v_total_seconds - (v_duration_minutes * 60);
		
		-- Формируем строку с правильными склонениями
		v_time_str := '';
		
		IF v_duration_days > 0 THEN
			IF v_duration_days = 1 THEN
				v_time_str := v_time_str || v_duration_days || ' день ';
			ELSIF v_duration_days BETWEEN 2 AND 4 THEN
				v_time_str := v_time_str || v_duration_days || ' дня ';
			ELSE
				v_time_str := v_time_str || v_duration_days || ' дней ';
			END IF;
		END IF;
		
		IF v_duration_hours > 0 THEN
			IF v_duration_hours = 1 THEN
				v_time_str := v_time_str || v_duration_hours || ' час ';
			ELSIF v_duration_hours BETWEEN 2 AND 4 THEN
				v_time_str := v_time_str || v_duration_hours || ' часа ';
			ELSE
				v_time_str := v_time_str || v_duration_hours || ' часов ';
			END IF;
		END IF;
		
		IF v_duration_minutes > 0 THEN
			IF v_duration_minutes = 1 THEN
				v_time_str := v_time_str || v_duration_minutes || ' минута ';
			ELSIF v_duration_minutes BETWEEN 2 AND 4 THEN
				v_time_str := v_time_str || v_duration_minutes || ' минуты ';
			ELSE
				v_time_str := v_time_str || v_duration_minutes || ' минут ';
			END IF;
		END IF;
		
		IF v_duration_seconds > 0 THEN
			IF v_duration_seconds = 1 THEN
				v_time_str := v_time_str || v_duration_seconds || ' секунда';
			ELSIF v_duration_seconds BETWEEN 2 AND 4 THEN
				v_time_str := v_time_str || v_duration_seconds || ' секунды';
			ELSE
				v_time_str := v_time_str || v_duration_seconds || ' секунд';
			END IF;
		END IF;
		
		-- Если время меньше секунды
		IF v_time_str IS NULL OR LENGTH(TRIM(v_time_str)) = 0 THEN
			v_time_str := '0 секунд';
		END IF;
		
		RETURN TRIM(v_time_str);
		
	EXCEPTION
		WHEN OTHERS THEN
			SAVE_LOG(NULL, 'ERROR', 'SKYSCRAPERS_UTILS.FORMAT_GAME_DURATION', 
				'Ошибка при форматировании времени. Start: ' || TO_CHAR(v_start_time, 'DD.MM.YYYY HH24:MI:SS') || 
				', End: ' || TO_CHAR(v_end_time, 'DD.MM.YYYY HH24:MI:SS') || ', SQLERRM: ' || SQLERRM);
			RETURN 'ошибка расчета времени';
	END FORMAT_GAME_DURATION;
	----------------------------------------------------------
        
END SKYSCRAPERS_UTILS;