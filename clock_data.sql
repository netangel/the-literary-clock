PRAGMA foreign_keys=OFF;
BEGIN TRANSACTION;

DROP TABLE IF EXISTS `quotes`;
CREATE TABLE `quotes` (
row_id integer primary key,
time_string TIME,
quote text,
author varchar(255),
book_title varchar(255),
submited_by varchar(255),
submited_on datetime,
quote_checksum varchar(32),
approved tinyint(1) default 0,
language char(2) default 'en');
CREATE INDEX IF NOT EXISTS time_index on quotes (time_string);
CREATE INDEX IF NOT EXISTS checksum_index on quotes (quote_checksum);
CREATE INDEX IF NOT EXISTS approved_index on quotes (approved);
CREATE INDEX IF NOT EXISTS submited_by_index on quotes (submited_by);
CREATE INDEX IF NOT EXISTS language_index on quotes (submited_by);

COMMIT;
