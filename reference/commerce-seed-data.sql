-- RabTech SQL internship starter database. Compatible with PostgreSQL.
CREATE TABLE customers (
  customer_id INTEGER PRIMARY KEY,
  customer_name VARCHAR(100) NOT NULL,
  city VARCHAR(80) NOT NULL,
  joined_on DATE NOT NULL
);

CREATE TABLE orders (
  order_id INTEGER PRIMARY KEY,
  customer_id INTEGER NOT NULL REFERENCES customers(customer_id),
  ordered_on DATE NOT NULL,
  order_status VARCHAR(20) NOT NULL CHECK (order_status IN ('PLACED', 'PAID', 'CANCELLED')),
  amount_inr NUMERIC(10,2) NOT NULL CHECK (amount_inr >= 0)
);

INSERT INTO customers VALUES
  (1, 'Aarav Mehta', 'Chennai', '2026-01-03'),
  (2, 'Diya Nair', 'Kochi', '2026-01-10'),
  (3, 'Kabir Shah', 'Pune', '2026-02-02'),
  (4, 'Meera Iyer', 'Bengaluru', '2026-02-15');

INSERT INTO orders VALUES
  (101, 1, '2026-03-01', 'PAID', 1499.00),
  (102, 1, '2026-03-17', 'CANCELLED', 799.00),
  (103, 2, '2026-03-05', 'PAID', 2499.00),
  (104, 3, '2026-04-02', 'PLACED', 999.00),
  (105, 4, '2026-04-06', 'PAID', 1899.00),
  (106, 2, '2026-04-08', 'PAID', 599.00);
