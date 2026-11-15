-- 02. 화면(View)별 조회용 뷰
USE cinema;

-- 🔹 상영관별 좌석 수 뷰
CREATE VIEW Auditorium_seat_count AS
SELECT
    auditorium_id,
    COUNT(*) AS seat_count
FROM Seat
GROUP BY auditorium_id;

-- 영화 요약(평균 평점/리뷰 수 포함)
CREATE VIEW v_movie_summary AS
SELECT
  m.movie_id,
  m.name,
  m.running_time,
  m.age_rating,
  m.total_admissions,
  m.release_date,
  m.end_date,
  m.url,
  ROUND(AVG(r.score), 2)      AS avg_rating,
  COUNT(r.rating_id)          AS rating_count
FROM Movie m
LEFT JOIN Rating r ON r.movie_id = m.movie_id
GROUP BY m.movie_id;

-- 진행 중 프로모션(오늘 기준)
CREATE VIEW v_home_promotions AS
SELECT
  promotion_id,
  name,
  start_date,
  end_date,
  url
FROM Promotion
WHERE CURDATE() BETWEEN start_date AND end_date;

DROP VIEW IF EXISTS main;
CREATE VIEW main AS
SELECT 
    m.movie_id,
    m.name               AS movie_name,
    m.running_time,
    m.age_rating,
    m.total_admissions,
    m.release_date,
    m.end_date,
    m.url                AS movie_url,
    m.avg_rating,
    m.rating_count
FROM v_movie_summary AS m
ORDER BY m.total_admissions DESC;

CREATE VIEW screening_overview AS
SELECT
    sc.screening_id,
    sc.start_time,
    sc.end_time,
    mv.movie_id,
    mv.name        AS movie_name,
    mv.url         AS movie_url,
    th.theater_id,
    th.name        AS theater_name,
    a.auditorium_id,
    a.type         AS auditorium_type,
    ascnt.total_seats,
    COALESCE(ascnt.total_seats, 0) - COALESCE(bc.booked_count, 0) AS remaining_seats
FROM Screening sc
JOIN Movie mv ON mv.movie_id = sc.movie_id
JOIN Auditorium a ON a.auditorium_id = sc.auditorium_id
JOIN Theater th ON th.theater_id = a.theater_id
JOIN (
    SELECT auditorium_id, COUNT(*) AS total_seats
    FROM Seat
    GROUP BY auditorium_id
) AS ascnt ON ascnt.auditorium_id = a.auditorium_id
LEFT JOIN (
    SELECT screening_id, COUNT(*) AS booked_count
    FROM Booked
    GROUP BY screening_id
) AS bc ON bc.screening_id = sc.screening_id;

CREATE VIEW screening_seat AS
SELECT
    sc.screening_id,
    st.seat_id,
    st.row_s,
    st.col_s,
    st.type        AS seat_type,
    CASE WHEN b.booked_id IS NULL THEN 0 ELSE 1 END AS is_booked
FROM Screening sc
JOIN Seat st       ON st.auditorium_id = sc.auditorium_id
LEFT JOIN Booked b ON b.seat_id = st.seat_id
                  AND b.screening_id = sc.screening_id;

CREATE VIEW mypage AS
SELECT
    u.user_id,
    u.name        AS user_name,
    g.grade       AS current_grade,
    u.total_spent,
    u.total_stamp,
    IFNULL(c.active_coupon_cnt, 0) AS active_coupon_cnt
FROM `User` u
LEFT JOIN Grade g
    ON u.grade_id = g.grade_id
LEFT JOIN (
    SELECT
        user_id,
        COUNT(*) AS active_coupon_cnt
    FROM User_coupon
    WHERE status = 'ACTIVE'
      AND expires_at > NOW()
    GROUP BY user_id
) c
    ON u.user_id = c.user_id;
