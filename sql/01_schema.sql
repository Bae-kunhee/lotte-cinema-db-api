-- 01. 데이터베이스 · 테이블 · 인덱스
DROP DATABASE IF EXISTS cinema;
CREATE DATABASE cinema;
USE cinema;

CREATE TABLE Grade (
    grade_id     INT PRIMARY KEY,
    grade        VARCHAR(50) NOT NULL
);

CREATE TABLE `User` (
    user_id      INT PRIMARY KEY,
    name         VARCHAR(100) NOT NULL,
    total_spent  INT NOT NULL DEFAULT 0,
    total_stamp  INT NOT NULL DEFAULT 0,
    grade_id     INT,
    FOREIGN KEY (grade_id)
        REFERENCES Grade(grade_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL
);

CREATE TABLE Coupon (
    coupon_id      INT PRIMARY KEY,
    coupon         VARCHAR(100) NOT NULL,
    benefit_type   ENUM('PERCENT', 'AMOUNT', 'FREE_ITEM') NOT NULL,
    benefit_value  INT NOT NULL DEFAULT 0
);

CREATE TABLE User_coupon (
    user_coupon_id INT PRIMARY KEY,
    user_id        INT NOT NULL,
    coupon_id      INT NOT NULL,
    expires_at     DATETIME NOT NULL,
    status         ENUM('ACTIVE', 'USED', 'EXPIRED', 'CANCELLED') NOT NULL DEFAULT 'ACTIVE',
    CONSTRAINT fk_uc_user
        FOREIGN KEY (user_id)
        REFERENCES `User`(user_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT fk_uc_coupon
        FOREIGN KEY (coupon_id)
        REFERENCES Coupon(coupon_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
);

CREATE TABLE Movie (
    movie_id          INT PRIMARY KEY,
    name              VARCHAR(200) NOT NULL,
    running_time      INT NOT NULL,
    age_rating        INT NOT NULL,
    total_admissions  INT NOT NULL DEFAULT 0,
    release_date      DATE,
    end_date          DATE,
    url               VARCHAR(500)
);

CREATE TABLE Rating (
    rating_id   INT PRIMARY KEY,
    movie_id    INT NOT NULL,
    user_id     INT NOT NULL,
    score       INT NOT NULL CHECK (score BETWEEN 1 AND 10),
    comment     VARCHAR(200),
    CONSTRAINT fk_rating_movie
        FOREIGN KEY (movie_id)
        REFERENCES Movie(movie_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_rating_user
        FOREIGN KEY (user_id)
        REFERENCES `User`(user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
);

CREATE TABLE Promotion (
    promotion_id  INT PRIMARY KEY,
    name          VARCHAR(200) NOT NULL,
    start_date    DATE NOT NULL,
    end_date      DATE NOT NULL,
    url           VARCHAR(500)
);

CREATE TABLE Theater (
    theater_id  INT PRIMARY KEY,
    name        VARCHAR(200) NOT NULL,
    address     VARCHAR(500)
);

CREATE TABLE Auditorium (
    auditorium_id  INT PRIMARY KEY,
    theater_id     INT NOT NULL,
    type           VARCHAR(50) NOT NULL,
    CONSTRAINT fk_aud_theater
        FOREIGN KEY (theater_id)
        REFERENCES Theater(theater_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

CREATE TABLE Screening (
    screening_id   INT PRIMARY KEY,
    auditorium_id  INT NOT NULL,
    movie_id       INT NOT NULL,
    start_time     DATETIME NOT NULL,
    end_time       DATETIME NOT NULL,
    CONSTRAINT fk_scr_aud
        FOREIGN KEY (auditorium_id)
        REFERENCES Auditorium(auditorium_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT fk_scr_movie
        FOREIGN KEY (movie_id)
        REFERENCES Movie(movie_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT chk_time_order CHECK (start_time < end_time)
);

CREATE TABLE Seat (
    seat_id        INT PRIMARY KEY,
    auditorium_id  INT NOT NULL,
    col_s          VARCHAR(20) NOT NULL,
    row_s          VARCHAR(20) NOT NULL,
    `type`         VARCHAR(50) NOT NULL,
    UNIQUE KEY uq_seat (auditorium_id, col_s, row_s),
    CONSTRAINT fk_seat_aud
        FOREIGN KEY (auditorium_id)
        REFERENCES Auditorium(auditorium_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

CREATE TABLE Booked (
    booked_id     INT PRIMARY KEY,
    seat_id       INT NOT NULL,
    user_id       INT NOT NULL,
    screening_id  INT NOT NULL,
    price         INT NOT NULL,
    CONSTRAINT fk_book_seat
        FOREIGN KEY (seat_id)
        REFERENCES Seat(seat_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_book_user
        FOREIGN KEY (user_id)
        REFERENCES `User`(user_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT fk_book_screen
        FOREIGN KEY (screening_id)
        REFERENCES Screening(screening_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);
ALTER TABLE Booked
  ADD UNIQUE KEY uq_booked_seat_screening (seat_id, screening_id);

-- 🔹 인덱스 설정
CREATE INDEX ix_screening_time   ON Screening(start_time, end_time);
CREATE INDEX ix_screening_movie  ON Screening(movie_id);
CREATE INDEX ix_aud_theater      ON Auditorium(theater_id);
CREATE INDEX ix_seat_aud         ON Seat(auditorium_id);
CREATE INDEX ix_book_screen      ON Booked(screening_id);
CREATE INDEX ix_book_seat        ON Booked(seat_id);
