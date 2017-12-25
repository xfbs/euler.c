def gcd(a, b):
   while b != 0:
      a, b = b, a % b
   return a

def lcm(a, b):
   return a * b // gcd(a, b)

def sum_divisible(m, n):
   m = m - (m % n)
   return m * ((m // n) + 1) // 2

def solve(m, a, b):
   return sum_divisible(m, a) + sum_divisible(m, b) - sum_divisible(m, lcm(a, b))
