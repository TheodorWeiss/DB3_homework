-- Задача 1
-- Вывести распределение (количество) клиентов по сферам деятельности, 
-- отсортировав результат по убыванию количества.

SELECT
    job_industry_category,
    COUNT(customer_id) AS customer_count
FROM customer
GROUP BY job_industry_category
ORDER BY customer_count DESC;

-- Задача 2
-- Найти общую сумму дохода (list_price*quantity) по всем подтвержденным заказам 
-- за каждый месяц по сферам деятельности клиентов. Отсортировать результат по году, 
-- месяцу и сфере деятельности.

SELECT    
    EXTRACT(YEAR  FROM o.order_date)  AS year,
    EXTRACT(MONTH FROM o.order_date)  AS month,
    c.job_industry_category,
    SUM(p.list_price*oi.quantity) AS total_revenue
    
FROM orders o
JOIN customer     c  ON c.customer_id = o.customer_id
JOIN order_items  oi ON oi.order_id   = o.order_id
JOIN product      p  ON p.product_id  = oi.product_id
WHERE o.order_status = 'Approved'
GROUP BY 
		job_industry_category,
		EXTRACT(YEAR  FROM o.order_date),
    	EXTRACT(MONTH FROM o.order_date)
ORDER by 
		year,
    	month,
    	c.job_industry_category;

-- Задача 3
-- Вывести количество уникальных онлайн-заказов для всех брендов в рамках подтвержденных заказов клиентов из сферы IT. 
-- Включить бренды, у которых нет онлайн-заказов от IT-клиентов, — для них должно быть указано количество 0.

SELECT
    p.brand,
    COUNT(
        DISTINCT CASE
            WHEN c.job_industry_category = 'IT'
                 AND o.online_order  IS TRUE
                 AND o.order_status = 'Approved'
            THEN o.order_id
        END
    ) AS it_online_order_count
FROM product p
LEFT JOIN order_items oi
    ON oi.product_id = p.product_id
LEFT JOIN orders o
    ON o.order_id = oi.order_id
LEFT JOIN customer c
    ON c.customer_id = o.customer_id
GROUP BY
    p.brand
ORDER BY
    it_online_order_count DESC,
    p.brand;

-- Задача 4
-- Найти по всем клиентам: сумму всех заказов (общего дохода), максимум, минимум и количество заказов, 
-- а также среднюю сумму заказа по каждому клиенту. Отсортировать результат по убыванию суммы всех заказов 
-- и количества заказов. Выполнить двумя способами: используя только GROUP BY и используя только оконные функции. 
-- Сравнить результат.

-- Способ 1
-- 1) Считаем сумму каждого заказа
WITH order_revenue AS (
    SELECT
        o.order_id,
        o.customer_id,
        SUM(p.list_price * oi.quantity) AS order_amount
    FROM orders o
    JOIN order_items oi ON oi.order_id  = o.order_id
    JOIN product      p  ON p.product_id = oi.product_id
    GROUP BY
        o.order_id,
        o.customer_id
)

-- 2) Агрегируем по клиенту
SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    COALESCE(SUM(orv.order_amount), 0)                  AS total_revenue,      -- сумма всех заказов
    MAX(orv.order_amount)                               AS max_order_amount,   -- максимум по одному заказу
    MIN(orv.order_amount)                               AS min_order_amount,   -- минимум по одному заказу
    COUNT(orv.order_id)                                 AS orders_count,       -- количество заказов
    AVG(orv.order_amount)                               AS avg_order_amount    -- средняя сумма заказа
FROM customer c
LEFT JOIN order_revenue orv
       ON orv.customer_id = c.customer_id
GROUP BY
    c.customer_id,
    c.first_name,
    c.last_name
ORDER BY
    total_revenue DESC,
    orders_count DESC;


-- Способ 2
-- 1) Считаем сумму каждого заказа (так же, как выше)
WITH order_revenue AS (
    SELECT
        o.order_id,
        o.customer_id,
        SUM(p.list_price * oi.quantity) AS order_amount
    FROM orders o
    JOIN order_items oi ON oi.order_id  = o.order_id
    JOIN product      p  ON p.product_id = oi.product_id
    GROUP BY
        o.order_id,
        o.customer_id
),

-- 2) Вешаем оконные функции по клиенту
customer_orders AS (
    SELECT
        c.customer_id,
        c.first_name,
        c.last_name,
        orv.order_id,
        orv.order_amount,
        SUM(orv.order_amount)  OVER (PARTITION BY c.customer_id) AS total_revenue,
        MAX(orv.order_amount)  OVER (PARTITION BY c.customer_id) AS max_order_amount,
        MIN(orv.order_amount)  OVER (PARTITION BY c.customer_id) AS min_order_amount,
        COUNT(orv.order_id)    OVER (PARTITION BY c.customer_id) AS orders_count,
        AVG(orv.order_amount)  OVER (PARTITION BY c.customer_id) AS avg_order_amount
    FROM customer c
    LEFT JOIN order_revenue orv
           ON orv.customer_id = c.customer_id
)

-- 3) Оставляем по одной строке на клиента
SELECT DISTINCT
    customer_id,
    first_name,
    last_name,
    COALESCE(total_revenue, 0) AS total_revenue,
    max_order_amount,
    min_order_amount,
    orders_count,
    avg_order_amount
FROM customer_orders
ORDER BY
    total_revenue DESC,
    orders_count DESC;


-- Задача 5
-- Найти имена и фамилии клиентов с топ-3 минимальной и топ-3 максимальной суммой транзакций
--  за весь период (учесть клиентов, у которых нет заказов, приняв их сумму транзакций за 0).


WITH order_revenue AS (
    SELECT
        o.order_id,
        o.customer_id,
        SUM(p.list_price * oi.quantity) AS order_amount
    FROM orders o
    JOIN order_items oi ON oi.order_id  = o.order_id
    JOIN product      p  ON p.product_id = oi.product_id
    GROUP BY
        o.order_id,
        o.customer_id
),
customer_revenue AS (
    SELECT
        c.customer_id,
        c.first_name,
        c.last_name,
        COALESCE(SUM(orv.order_amount), 0) AS total_revenue
    FROM customer c
    LEFT JOIN order_revenue orv
           ON orv.customer_id = c.customer_id
    GROUP BY
        c.customer_id,
        c.first_name,
        c.last_name
),
ranked AS (
    SELECT
        customer_id,
        first_name,
        last_name,
        total_revenue,
        ROW_NUMBER() OVER (ORDER BY total_revenue ASC,  customer_id) AS rn_min,
        ROW_NUMBER() OVER (ORDER BY total_revenue DESC, customer_id) AS rn_max
    FROM customer_revenue
)
SELECT
    customer_id,
    first_name,
    last_name,
    total_revenue
FROM ranked
WHERE rn_min <= 3      -- ровно 3 «самых бедных»
   OR rn_max <= 3      -- и 3 «самых богатых»
ORDER BY
    total_revenue,
    customer_id;


-- Задача 6
-- Вывести только вторые транзакции клиентов (если они есть) с помощью оконных функций. 
-- Если у клиента меньше двух транзакций, он не должен попасть в результат.


WITH customer_orders AS (
    SELECT
        o.order_id,
        o.customer_id,
        o.order_date,
        ROW_NUMBER() OVER (
            PARTITION BY o.customer_id
            ORDER BY o.order_date, o.order_id
        ) AS rn
    FROM orders o
)
SELECT
    co.order_id,
    co.order_date,
    c.customer_id,
    c.first_name,
    c.last_name
FROM customer_orders co
JOIN customer c
    ON c.customer_id = co.customer_id
WHERE co.rn = 2              -- только вторая транзакция
ORDER BY
    co.order_date,
    c.customer_id;


-- Задача 7
-- Вывести имена, фамилии и профессии клиентов, а также длительность максимального интервала (в днях) 
-- между двумя последовательными заказами. Исключить клиентов, у которых только один или меньше заказов.


WITH customer_orders AS (
    SELECT
        o.customer_id,
        o.order_id,
        o.order_date,
        LAG(o.order_date) OVER (
            PARTITION BY o.customer_id
            ORDER BY o.order_date, o.order_id
        ) AS prev_order_date
    FROM orders o
),
intervals AS (
    SELECT
        customer_id,
        order_id,
        order_date,
        prev_order_date,
        (order_date - prev_order_date) AS gap_days   -- интервал в днях
    FROM customer_orders
    WHERE prev_order_date IS NOT NULL               -- у первого заказа интервала нет
),
max_gap AS (
    SELECT
        customer_id,
        MAX(gap_days) AS max_gap_days
    FROM intervals
    GROUP BY customer_id
)

SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    c.job_title,
    mg.max_gap_days
FROM max_gap mg
JOIN customer c
    ON c.customer_id = mg.customer_id
WHERE mg.max_gap_days IS NOT NULL       -- отсечь клиентов с 0–1 заказом
ORDER BY
    mg.max_gap_days DESC,
    c.customer_id;

-- Задача 8
-- Найти топ-5 клиентов (по общему доходу) в каждом сегменте благосостояния (wealth_segment). 
-- Вывести имя, фамилию, сегмент и общий доход. Если в сегменте менее 5 клиентов, вывести всех.


WITH order_revenue AS (
    -- Считаем сумму по каждому заказу
    SELECT
        o.order_id,
        o.customer_id,
        SUM(p.list_price * oi.quantity) AS order_amount
    FROM orders o
    JOIN order_items oi ON oi.order_id  = o.order_id
    JOIN product      p ON p.product_id = oi.product_id
    GROUP BY
        o.order_id,
        o.customer_id
),
customer_revenue AS (
    -- Считаем общий доход по каждому клиенту
    -- Клиенты без заказов получают total_revenue = 0
    SELECT
        c.customer_id,
        c.first_name,
        c.last_name,
        c.wealth_segment,
        COALESCE(SUM(orv.order_amount), 0) AS total_revenue
    FROM customer c
    LEFT JOIN order_revenue orv
           ON orv.customer_id = c.customer_id
    GROUP BY
        c.customer_id,
        c.first_name,
        c.last_name,
        c.wealth_segment
),
ranked AS (
    -- Присваиваем ранг внутри сегмента по убыванию дохода
    SELECT
        customer_id,
        first_name,
        last_name,
        wealth_segment,
        total_revenue,
        RANK() OVER (
            PARTITION BY wealth_segment
            ORDER BY total_revenue DESC
        ) AS rnk
    FROM customer_revenue
)

SELECT
    customer_id,
    first_name,
    last_name,
    wealth_segment,
    total_revenue
FROM ranked
WHERE rnk <= 5               -- топ-5 в каждом сегменте; если клиентов <5, попадут все
ORDER BY
    wealth_segment,
    total_revenue DESC,
    customer_id;

