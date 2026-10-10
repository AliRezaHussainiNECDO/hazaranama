# پورت پایتونیِ gregorianToAfghan در lib/core/afghan_calendar.dart
M=['حمل','ثور','جوزا','سرطان','اسد','سنبله','میزان','عقرب','قوس','جدی','دلو','حوت']
FA='۰۱۲۳۴۵۶۷۸۹'
def fa(n): return ''.join(FA[int(c)] if c.isdigit() else c for c in str(n))
def g2a(gy,gm,gd):
    g=[0,31,59,90,120,151,181,212,243,273,304,334]
    gy2=gy+1 if gm>2 else gy
    jdn=355666+365*gy+(gy2+3)//4-(gy2+99)//100+(gy2+399)//400+gd+g[gm-1]
    jy=-1595+33*(jdn//12053); jdn%=12053; jy+=4*(jdn//1461); jdn%=1461
    if jdn>365: jy+=(jdn-1)//365; jdn=(jdn-1)%365
    if jdn<186: jm=1+jdn//31; jd=1+jdn%31
    else: jm=7+(jdn-186)//30; jd=1+(jdn-186)%30
    return jy,jm,jd
def label(gy,gm,gd):
    y,m,d=g2a(gy,gm,gd); return f'{fa(d)} {M[m-1]} {fa(y)}'
if __name__=='__main__':
    for t in [(2021,5,8),(1998,8,8),(1993,2,11),(2000,5,10),(2001,1,8),(2013,1,10),(2013,2,16),(2015,11,8),(2019,8,17),(2021,7,4),(2021,8,30),(2022,9,30),(2024,9,12),(2024,4,29),(2022,7,3),(2004,3,2),(1979,6,23),(1995,3,13)]:
        print(t,label(*t))
