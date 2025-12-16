--Представление для ежедневной таблицы дейлиборд

CREATE OR REPLACE VIEW V_DAILY_BOARD AS
SELECT
    ROW_NUMBER() OVER (
        ORDER BY 
            SKYSCRAPERS_UTILS.CALCULATE_SCORE(
                dl.SIZE_NUMBER, 
                ROUND((gs.END_TIME - gs.START_TIME) * 24 * 60, 1), 
                gstat.NAME
            ) DESC,
            ROUND((gs.END_TIME - gs.START_TIME) * 24 * 60, 1) ASC
    ) AS RANK,
    u.USERNAME,
    dl.DIFFICULTY_NAME,
    dl.SIZE_NUMBER || 'x' || dl.SIZE_NUMBER AS GRID_SIZE,
    gs.START_TIME,
    gs.END_TIME,
    SKYSCRAPERS_UTILS.FORMAT_GAME_DURATION(gs.START_TIME, gs.END_TIME) AS GAME_DURATION,
    gstat.NAME AS RESULT_STATUS,
    SKYSCRAPERS_UTILS.CALCULATE_SCORE(
        dl.SIZE_NUMBER,
        ROUND((gs.END_TIME - gs.START_TIME) * 24 * 60, 1),
        gstat.NAME
    ) AS SCORE
FROM GAME_SESSIONS gs
JOIN USERS u ON gs.USER_ID = u.ID
JOIN GAME_STATUSES gstat ON gs.STATUS_ID = gstat.ID
JOIN PUZZLES p ON gs.PUZZLE_ID = p.ID
JOIN DIFFICULTY_LEVELS dl ON p.DIFFICULTY_LEVEL_ID = dl.ID
WHERE p.IS_DAILY = 1
  AND TRUNC(gs.START_TIME) = TRUNC(SYSDATE)
  AND gs.END_TIME IS NOT NULL
  AND gstat.NAME = 'Победа'
ORDER BY SCORE DESC, ROUND((gs.END_TIME - gs.START_TIME) * 24 * 60, 1) ASC;

--Представление для общей таблицы лидеров (лидерборд)
CREATE OR REPLACE VIEW V_LEADERBOARD AS
WITH GameScores AS (
    SELECT
        gs.USER_ID,
        gs.END_TIME,
        p.DIFFICULTY_LEVEL_ID,
        SKYSCRAPERS_UTILS.CALCULATE_SCORE(
            dl.SIZE_NUMBER,
            ROUND((gs.END_TIME - gs.START_TIME) * 24 * 60, 1),
            gstat.NAME
        ) AS SCORE
    FROM GAME_SESSIONS gs
    JOIN GAME_STATUSES gstat ON gs.STATUS_ID = gstat.ID
    JOIN PUZZLES p ON gs.PUZZLE_ID = p.ID
    JOIN DIFFICULTY_LEVELS dl ON p.DIFFICULTY_LEVEL_ID = dl.ID
    WHERE gs.END_TIME IS NOT NULL
),
UserTotals AS (
    SELECT
        USER_ID,
        SUM(SCORE) AS TOTAL_SCORE,
        MAX(END_TIME) AS LAST_GAME_TIME
    FROM GameScores
    GROUP BY USER_ID
    HAVING SUM(SCORE) > 0
)
SELECT
    u.USERNAME,
    ut.TOTAL_SCORE,
    dl.DIFFICULTY_NAME AS LAST_GAME_DIFFICULTY,
    ut.LAST_GAME_TIME
FROM UserTotals ut
JOIN USERS u ON ut.USER_ID = u.ID
JOIN GAME_SESSIONS gs_last ON gs_last.USER_ID = ut.USER_ID AND gs_last.END_TIME = ut.LAST_GAME_TIME
JOIN PUZZLES p ON gs_last.PUZZLE_ID = p.ID
JOIN DIFFICULTY_LEVELS dl ON p.DIFFICULTY_LEVEL_ID = dl.ID
ORDER BY ut.TOTAL_SCORE DESC;

