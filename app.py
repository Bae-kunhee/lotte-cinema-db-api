import os

from flask import Flask, request
import pymysql
from datetime import datetime

app = Flask(__name__)

# DB 접속 공통 함수
def get_connection():
    return pymysql.connect(
        host=os.environ.get('DB_HOST', 'localhost'),
        port=int(os.environ.get('DB_PORT', 3306)),
        user=os.environ.get('DB_USER', 'root'),
        password=os.environ.get('DB_PASSWORD', ''),
        db=os.environ.get('DB_NAME', 'cinema'),
        cursorclass=pymysql.cursors.DictCursor
    )

# 1) 메인 화면용: main 뷰 
@app.route('/api/main', methods=['POST'])
def main_view():
    if not request.is_json:
        return {"error": "Invalid request: Missing JSON body."}, 400

    user_id = request.json.get("user_id")
    if user_id is None:
        return {"error": "Invalid request: 'user_id' is required."}, 400
    if not isinstance(user_id, int):
        return {"error": "Invalid request: 'user_id' must be an integer."}, 400

    conn = get_connection()
    try:
        with conn.cursor() as cur:
            sql = """
                SELECT *
                FROM main
                ORDER BY total_admissions DESC;
            """
            cur.execute(sql)
            rows = cur.fetchall()

            cur.execute(
                """
                SELECT user_id, name
                FROM `User`
                WHERE user_id = %s
                """,
                (user_id,),
            )
            user_info = cur.fetchone()
            if user_info is None:
                return {"error": "User not found."}, 404

    finally:
        conn.close()

    return {
        "movies": rows,
        "user": user_info,
    }

# 2) 상영 시간표/예매 정보: screening_overview 뷰 
@app.route('/api/movieTime', methods=['GET'])
def movie_time_view():
    date_str = request.args.get("date")
    if not date_str:
        return {"error": "Missing 'date' parameter (YYYY-MM-DD)"}, 400
    try:
        datetime.strptime(date_str, '%Y-%m-%d')
    except ValueError:
        return {"error": "Invalid date format. Please use YYYY-MM-DD."}, 400

    theater_id_param = request.args.get("theater_id")
    theater_id = None
    if theater_id_param is not None:
        try:
            theater_id = int(theater_id_param)
        except ValueError:
            return {"error": "Invalid request: 'theater_id' must be an integer."}, 400

    conn = get_connection()
    try:
        with conn.cursor() as cur:
            if theater_id is not None:
                sql = """
                    SELECT *
                    FROM screening_overview
                    WHERE DATE(start_time) = %s
                      AND theater_id = %s
                    ORDER BY start_time;
                """
                cur.execute(sql, (date_str, theater_id))
            else:
                sql = """
                    SELECT *
                    FROM screening_overview
                    WHERE DATE(start_time) = %s
                    ORDER BY start_time;
                """
                cur.execute(sql, (date_str,))
            rows = cur.fetchall()
    finally:
        conn.close()

    return rows

# 3) 상영 요약(상영 단위 정보): screening_overview 뷰
@app.route('/api/screenings/<int:screening_id>', methods=['GET'])
def screening_overview_view(screening_id):
    conn = get_connection()
    try:
        with conn.cursor(pymysql.cursors.DictCursor) as cur:
            sql_current = """
                SELECT *
                FROM screening_overview
                WHERE screening_id = %s;
            """
            cur.execute(sql_current, (screening_id,))
            current = cur.fetchone()

            if current is None:
                return {"error": "screening not found"}, 404

            sql_siblings = """
                SELECT *
                FROM screening_overview
                WHERE movie_id   = %s
                  AND theater_id = %s
                  AND DATE(start_time) = DATE(%s)
                  AND screening_id <> %s
                ORDER BY start_time;
            """
            cur.execute(
                sql_siblings,
                (
                    current["movie_id"],
                    current["theater_id"],
                    current["start_time"],
                    current["screening_id"],
                ),
            )
            siblings = cur.fetchall()

    finally:
        conn.close()

    return {
        "current": current,
        "screenings": siblings,
    }

# 4) 좌석 상태(좌석 맵): screening_seat 뷰
@app.route('/api/screenings/<int:screening_id>/seats', methods=['GET'])
def screening_seat_view(screening_id):
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            sql = """
                SELECT *
                FROM screening_seat
                WHERE screening_id = %s
                ORDER BY row_s, col_s;
            """
            cur.execute(sql, (screening_id,))
            rows = cur.fetchall()
    finally:
        conn.close()
    return rows


# 5) 마이페이지: mypage 뷰
@app.route('/api/mypage', methods=['POST'])
def mypage_view():
    if not request.is_json:
        return {"error": "Invalid request: Missing JSON body."}, 400
    user_id = request.json.get('user_id')
    if user_id is None:
        return {"error": "Invalid request: 'user_id' is required."}, 400
    if not isinstance(user_id, int):
        return {"error": "Invalid request: 'user_id' must be an integer."}, 400

    conn = get_connection()
    try:
        with conn.cursor() as cur:
            sql = """
                SELECT *
                FROM mypage
                WHERE user_id = %s
            """
            cur.execute(sql, (user_id,))
            row = cur.fetchone() 
    finally:
        conn.close()

    if row is None:
        return {"error": "User not found."}, 404

    total_spent = row['total_spent']

    if total_spent < 260000:
        current_grade = '일반'
        next_grade = 'VIP'
        amount_to_next = 260000 - total_spent
    elif total_spent < 520000:
        current_grade = 'VIP'
        next_grade = 'VVIP'
        amount_to_next = 520000 - total_spent
    elif total_spent < 840000:
        current_grade = 'VVIP'
        next_grade = 'Gold'
        amount_to_next = 840000 - total_spent
    elif total_spent < 1240000:
        current_grade = 'Gold'
        next_grade = 'Platinum'
        amount_to_next = 1240000 - total_spent
    else:
        current_grade = 'Platinum'
        next_grade = None
        amount_to_next = 0

    row['current_grade'] = current_grade
    row['next_grade'] = next_grade
    row['amount_to_next'] = amount_to_next

    return row


# 6) 진행 중 프로모션: v_home_promotions 뷰 (마이페이지, 메인화면 둘 다 이용)
@app.route('/api/promotions', methods=['GET'])
def home_promotions_view():
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            sql = """
                SELECT *
                FROM v_home_promotions;
            """
            cur.execute(sql)
            rows = cur.fetchall() 
    finally:
        conn.close()
    return rows

# 7) 영화관 목록: Theater 테이블
@app.route('/api/theaters', methods=['GET'])
def theater_list_view():
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            sql = """
                SELECT theater_id, name, address
                FROM Theater
                ORDER BY name;
            """
            cur.execute(sql)
            rows = cur.fetchall()
    finally:
        conn.close()
    return rows

if __name__ == "__main__":
    app.run()
