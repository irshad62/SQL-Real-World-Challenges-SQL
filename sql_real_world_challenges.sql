
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS payments;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS logins;
DROP TABLE IF EXISTS customers;

-- Customers Table
CREATE TABLE customers (
    customer_id INT PRIMARY KEY,
    customer_name VARCHAR(50),
    email VARCHAR(100),
    signup_date DATE,
    region VARCHAR(30)
);

-- Products Table
CREATE TABLE products (
    product_id INT PRIMARY KEY,
    product_name VARCHAR(50),
    category VARCHAR(30),
    price DECIMAL(10,2)
);

-- Orders Table
CREATE TABLE orders (
    order_id INT PRIMARY KEY,
    customer_id INT,
    order_date DATE,
    total_amount DECIMAL(10,2),
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

-- Order Items Table
CREATE TABLE order_items (
    order_item_id INT PRIMARY KEY,
    order_id INT,
    product_id INT,
    quantity INT,
    FOREIGN KEY (order_id) REFERENCES orders(order_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

-- Payments Table
CREATE TABLE payments (
    payment_id INT PRIMARY KEY,
    order_id INT,
    amount DECIMAL(10,2),
    payment_date DATE,
    FOREIGN KEY (order_id) REFERENCES orders(order_id)
);

-- Logins Table
CREATE TABLE logins (
    login_id INT PRIMARY KEY,
    customer_id INT,
    login_date DATE,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

-- =============================================
-- 2. SAMPLE DATA INSERTION
-- =============================================

INSERT INTO customers VALUES
(1, 'Amit Sharma', 'amit@example.com', '2023-05-10', 'North'),
(2, 'Priya Singh', 'priya@example.com', '2023-06-15', 'South'),
(3, 'Rahul Mehta', 'rahul@example.com', '2023-07-01', 'East'),
(4, 'Sneha Gupta', 'sneha@example.com', '2023-08-20', 'West'),
(5, 'Arjun Yadav', 'arjun@example.com', '2023-09-05', 'North');

INSERT INTO products VALUES
(101, 'Laptop', 'Electronics', 60000),
(102, 'Smartphone', 'Electronics', 25000),
(103, 'Headphones', 'Electronics', 3000),
(104, 'Shoes', 'Fashion', 2000),
(105, 'Watch', 'Fashion', 5000);

INSERT INTO orders VALUES
(1001, 1, '2024-01-15', 85000),
(1002, 2, '2024-02-10', 25000),
(1003, 1, '2024-03-05', 60000),
(1004, 3, '2024-04-12', 5000),
(1005, 4, '2024-04-15', 3000);

INSERT INTO order_items VALUES
(1, 1001, 101, 1),
(2, 1001, 105, 1),
(3, 1002, 102, 1),
(4, 1003, 101, 1),
(5, 1004, 105, 1),
(6, 1005, 103, 1);

INSERT INTO payments VALUES
(201, 1001, 85000, '2024-01-15'),
(202, 1002, 25000, '2024-02-10'),
(203, 1003, 60000, '2024-03-05'),
(204, 1004, 5000, '2024-04-12'),
(205, 1005, 3000, '2024-04-15');

INSERT INTO logins VALUES
(301, 1, '2024-04-10'),
(302, 1, '2024-04-11'),
(303, 2, '2024-04-11'),
(304, 3, '2024-04-12'),
(305, 5, '2024-04-12');

-- =============================================
-- 3. REAL-WORLD SQL CHALLENGES
-- =============================================

-- 1. Find the second highest transaction amount (Subquery)
SELECT MAX(amount) AS second_highest_payment
FROM payments
WHERE amount < (SELECT MAX(amount) FROM payments);

-- 1b. Find 2nd highest using OFFSET LIMIT
SELECT DISTINCT amount AS second_highest_payment
FROM payments
ORDER BY amount DESC
LIMIT 1 OFFSET 1;

-- 1c. Find Nth highest without LIMIT/TOP
WITH RankedValues AS (
    SELECT amount,
           ROW_NUMBER() OVER (ORDER BY amount DESC) AS rnk
    FROM payments
)
SELECT amount
FROM RankedValues
WHERE rnk = 5;

-- 2. Find customers who purchased the same product more than once
SELECT 
    c.customer_id,
    oi.product_id,
    COUNT(*) AS total_orders
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY c.customer_id, oi.product_id
HAVING COUNT(*) > 1;

-- 3. Customers who registered but never placed orders
SELECT c.customer_id, c.customer_name
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
WHERE o.order_id IS NULL;

-- 4. Daily Active Users (DAU)
SELECT 
    login_date,
    COUNT(DISTINCT customer_id) AS daily_active_users
FROM logins
GROUP BY login_date
ORDER BY login_date;

-- 5. Month-over-Month Revenue Growth %
WITH MonthlyRevenue AS (
    SELECT DATE_TRUNC('month', order_date) AS month,
           SUM(total_amount) AS revenue
    FROM orders
    GROUP BY DATE_TRUNC('month', order_date)
),
RevenueWithLag AS (
    SELECT month, revenue,
           LAG(revenue) OVER (ORDER BY month) AS prev_month_revenue
    FROM MonthlyRevenue
)
SELECT month, revenue, prev_month_revenue,
       ROUND(
           CASE WHEN prev_month_revenue IS NULL OR prev_month_revenue = 0
                THEN NULL
                ELSE ((revenue - prev_month_revenue) / prev_month_revenue) * 100
           END, 2
       ) AS mom_growth_percent
FROM RevenueWithLag;

-- 6. Latest order per customer (ROW_NUMBER)
WITH ranked AS (
    SELECT customer_id, order_id, order_date, total_amount,
           ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date DESC) AS rnk
    FROM orders
)
SELECT * FROM ranked WHERE rnk = 1;

-- 7. Products whose sales dropped compared to previous month
WITH MonthlySales AS (
    SELECT DATE_TRUNC('month', o.order_date) AS month,
           oi.product_id,
           SUM(oi.quantity) AS total_sales
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    GROUP BY DATE_TRUNC('month', o.order_date), oi.product_id
),
Sales AS (
    SELECT product_id, month, total_sales,
           LAG(total_sales) OVER (PARTITION BY product_id ORDER BY month) AS prev_month_sales
    FROM MonthlySales
)
SELECT * FROM Sales
WHERE total_sales < prev_month_sales;

-- 8. Classify customers into spending categories
WITH CustomerSpend AS (
    SELECT customer_id, SUM(total_amount) AS total_spend
    FROM orders
    GROUP BY customer_id
)
SELECT customer_id, total_spend,
       CASE WHEN total_spend >= 10000 THEN 'High Spender'
            WHEN total_spend >= 5000 THEN 'Medium Spender'
            ELSE 'Low Spender'
       END AS spend_category
FROM CustomerSpend
ORDER BY total_spend DESC;

-- 9. Most popular product category in each region
WITH CategorySales AS (
    SELECT c.region, p.category, SUM(oi.quantity) AS total_units_sold
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    JOIN products p ON oi.product_id = p.product_id
    JOIN customers c ON o.customer_id = c.customer_id
    GROUP BY c.region, p.category
),
RankedCategories AS (
    SELECT region, category, total_units_sold,
           ROW_NUMBER() OVER (PARTITION BY region ORDER BY total_units_sold DESC) AS rn
    FROM CategorySales
)
SELECT region, category AS most_popular_category, total_units_sold
FROM RankedCategories
WHERE rn = 1;

-- 10. Customers who ordered last year but not this year
WITH LastYear AS (
    SELECT DISTINCT customer_id
    FROM orders
    WHERE EXTRACT(YEAR FROM order_date) = 2024
),
ThisYear AS (
    SELECT DISTINCT customer_id
    FROM orders
    WHERE EXTRACT(YEAR FROM order_date) = 2025
)
SELECT customer_id FROM LastYear
WHERE customer_id NOT IN (SELECT customer_id FROM ThisYear);

-- 11. Cumulative sales month by month
WITH MonthlySales AS (
    SELECT DATE_TRUNC('month', order_date) AS month,
           SUM(total_amount) AS monthly_sales
    FROM orders
    GROUP BY DATE_TRUNC('month', order_date)
)
SELECT month, monthly_sales,
       SUM(monthly_sales) OVER (ORDER BY month) AS cumulative_sales
FROM MonthlySales
ORDER BY month;

-- 12. Detect duplicate transactions
WITH RankedTransactions AS (
    SELECT p.payment_id, o.customer_id, oi.product_id, DATE(o.order_date) AS order_date,
           ROW_NUMBER() OVER (PARTITION BY o.customer_id, oi.product_id, DATE(o.order_date)
                              ORDER BY p.payment_id) AS rn
    FROM payments p
    JOIN orders o ON p.order_id = o.order_id
    JOIN order_items oi ON o.order_id = oi.order_id
)
SELECT * FROM RankedTransactions WHERE rn > 1;

-- =============================================
-- END OF PROJECT
-- =============================================

