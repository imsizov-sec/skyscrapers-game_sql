--Крон создания игры дня
BEGIN
  DBMS_SCHEDULER.CREATE_JOB(
	job_name => 'SKYSCRAPERS_DAILY_PUZZLE_JOB',
	job_type => 'STORED_PROCEDURE',
	job_action => 'SKYSCRAPERS_UTILS.SET_DAILY_GAME',
	start_date => TO_TIMESTAMP_TZ('2025-11-30 00:00:00.0 Europe/Moscow', 'yyyy-mm-dd hh24:mi:ss.ff tzr'),
	comments => 'Запуск процедуры для установки "Пазла дня"',
	enabled => TRUE
);
END;

--Крон избежания простаивания игровой сессии
BEGIN
  DBMS_SCHEDULER.CREATE_JOB(
	job_name => 'SKYSCRAPERS_TIMEOUT_JOB',
	job_type => 'PLSQL_BLOCK',
	job_action => 'BEGIN SKYSCRAPERS_UTILS.CHECK_USER_ACTIVE_GAME; END;',
	start_date => TO_TIMESTAMP_TZ('2025-11-17 23:24:34.683 +3:00', 'yyyy-mm-dd hh24:mi:ss.ff tzr'),
	repeat_interval => 'FREQ=MINUTELY; INTERVAL=1',
	comments => 'Завершает игровые сессии, неактивные более 15 минут.',
	enabled => TRUE
);
END;

