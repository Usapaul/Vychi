module ABfunctions
use mprecision

contains

function A(n,j)
implicit none
integer, intent(in) :: n, j
integer :: i
real(mp) :: A
real(mp) :: integral
!---------------------------------------
call integralf(0.0_mp,1.0_mp,Aintfun,integral)
A=(-1.0_mp)**j/product((/(i,i=1,j)/))/product((/(i,i=1,n-1-j)/))*integral

contains

function Aintfun(z)
implicit none
real(mp), intent(in) :: z
real(mp) :: Aintfun
integer :: i
!---------------------------------------
Aintfun=product((/(z+i,i=0,n-1)/))/(z+j)

end function Aintfun

end function A

!=======================================

function B(n,j)
implicit none
integer, intent(in) :: n, j
integer :: i
real(mp) :: B
real(mp) :: integral
!---------------------------------------
call integralf(0.0_mp,1.0_mp,Bintfun,integral)
B=(-1.0_mp)**(j+1)/product((/(i,i=1,j+1)/))/product((/(i,i=1,n-2-j)/))*integral

contains

function Bintfun(z)
implicit none
real(mp), intent(in) :: z
real(mp) :: Bintfun
integer :: i
!---------------------------------------
Bintfun=product((/(z+i,i=-1,n-2)/))/(z+j)

end function Bintfun

end function B

!=======================================

subroutine integralf(a0,b0,f,r)
! *** Процедура считает интеграл от f на [a0,b0] по методу Гаусса (n=5)
implicit none
integer, parameter :: n=5
real(mp), intent(in) :: a0, b0
real(mp), intent(out) :: r
real(mp), dimension(1:n) :: A, t
integer :: i
character(2) :: num
interface
function f(x)
use mprecision
real(mp), intent(in) :: x
real(mp) :: f
end function
end interface
!---------------------------------------
A(1)=0.236926794; t(1)=0.906179845
A(2)=0.236926794; t(2)=-0.906179845
A(3)=0.478628963; t(3)=0.538469315
A(4)=0.478628904; t(4)=-0.538469315
A(5)=0.568888545; t(5)=0.00000000
! Рассчет интеграла по формуле Гаусса. Функция f масштабирована под отрезок [-1,1]
r=0
do i=1,n
    r=r+A(i)*(b0-a0)/2*f(t(i)*(b0-a0)/2+(a0+b0)/2)
enddo

end subroutine integralf


end module ABfunctions
module adams
use ABfunctions
use ffunction
use newtonmethod
use rungekut

contains

subroutine extradams(X0,t0,Xnew,X)
! *** Процедура находит вектор Xnew(t0+h) из вектора X0(t0)
implicit none
real(mp), dimension(1:), intent(in) :: X0
real(mp), intent(in) :: t0
real(mp), dimension(1:size(X0)), intent(out) :: Xnew
real(mp), dimension(-Nextradams+1:0,1:size(X0)) :: X
real(mp), dimension(1:size(X0)) :: r
integer :: j, n

n=Nextradams
!---------------------------------------
r=0
do j=-n+1,0
    r=r+A(n,-j)*f(t0+h*j,X(j,:))
enddo
Xnew=X0+h*r

end subroutine extradams

subroutine interadams(X0,t0,Xnew,X)
! *** Процедура находит вектор Xnew(t0+h) из вектора X0(t0)
implicit none
real(mp), dimension(1:), intent(in) :: X0
real(mp), intent(in) :: t0
real(mp), dimension(1:size(X0)), intent(out) :: Xnew
real(mp), dimension(-Ninteradams+2:1,1:size(X0)) :: X
real(mp), dimension(1:size(X0)) :: r
integer :: j, n

n=Ninteradams
!---------------------------------------
r=0
do j=-n+2,0
    r=r+B(n,-j)*f(t0+h*j,X(j,:))
enddo
!---------------------------------------
call newton(X0,10000,Xnew,ft)


contains

function ft(X) result(ff)
! *** Функция ft(x) равна функции f(t,x) при фиксированном t (t0+h)
implicit none
real(mp), dimension(1:), intent(in) :: X
real(mp), dimension(1:size(X)) :: ff

ff=r*h+h*B(Ninteradams,-1)*f(t0+h,X)-X0-X

end function ft

end subroutine interadams

end module adams
module ffunction
use mprecision

implicit none
integer, parameter :: ndim=3
integer :: i
real(mp) :: tdata=4.0_mp
real(mp), dimension(ndim) :: Xdata=(/(1.0_mp,i=1,ndim)/)
real(mp) :: h=0.1_mp**(2)
integer :: Nextradams=4
integer :: Ninteradams=4

contains

function f(t,X) result(Y)
implicit none
real(mp), dimension(1:), intent(in) :: X
real(mp), intent(in) :: t
real(mp), dimension(1:size(X)) :: Y
integer :: i, n

n=size(X)
!---------------------------------------
Y=0
Y(1)=cos(X(1))*abs(X(1))-0.1_mp**(5)*t  ! Такая функция придумана для примера

end function f

end module ffunctionprogram diffur
use rungekut
use adams
use ffunction

! *** Дана система: dX/dt=f(t,X). Производится интегрирование системы с постоянным шагом интегрирования

implicit none
real(mp) :: t
real(mp), dimension(1:size(Xdata)) :: X, Xnew
!real(mp), dimension(1:Nextradams,1:size(Xdata)) :: Xae
!real(mp), dimension(1:Ninteradams,1:size(Xdata)) :: Xai
real(mp), allocatable :: Xae(:,:), Xai(:,:)
character(2) :: choice ! Переменная служит для выбора метода (rk, ae, ai)
integer :: j

allocate(Xae(-Nextradams+1:0,1:size(Xdata)),Xai(-Ninteradams+2:1,1:size(Xdata)))


call getarg(1,choice)
!---------------------------------------
select case(choice)
case('rk')
open(100,file='rk.dat')
    write(100,*) 0.0_mp, Xdata
    t=0.0_mp; X=Xdata ! Это начальные данные
    do while (t<tdata+h) ! Итегрирование ведется на полуинтервале [0,tdata+h)
        call rk4(X,t,Xnew) ! Xnew - новое вычисленное значение X в точке t
        write(100,*) t, Xnew
        t=t+h ! Новый шаг
        X=Xnew
    enddo
close(100)
!---------------------------------------
case('ae')
open(200,file='ae.dat')
    write(200,*) 0.0_mp, Xdata
    t=(Nextradams-1)*h
    Xae(-Nextradams+1,:)=Xdata ! Для начального набора X самый первый член берется равным начальным данным
    do j=-Nextradams+1,-1
        call rk4(Xae(j,:),t+h*j,Xae(j+1,:)) ! Создается начальный набор X
    enddo
    X=Xae(0,:)
    do while (t<tdata+h)
        call extradams(X,t,Xnew,Xae)
        forall (j=-Nextradams+1:-1) Xae(j,:)=Xae(j+1,:)
        Xae(0,:)=Xnew
        write(200,*) t, Xnew
        t=t+h
        X=Xnew
    enddo
close(200)
!---------------------------------------
case('ai')
open(300,file='ai.dat')
    write(300,*) 0.0_mp, Xdata
    t=(Ninteradams-2)*h
    Xai(-Ninteradams+2,:)=Xdata ! Для начального набора X самый первый член берется равным начальным данным
    do j=-Ninteradams+2,-1
        call rk4(Xai(j,:),t+h*j,Xai(j+1,:)) ! Создается начальный набор X
    enddo
    X=Xai(0,:)
    do while (t<tdata+h)
        call interadams(X,t,Xnew,Xai)
        forall (j=-Ninteradams+2:0) Xai(j,:)=Xai(j+1,:)
        Xai(1,:)=Xnew
        write(300,*) t, Xnew
        t=t+h
        X=Xnew
    enddo
close(300)
!---------------------------------------
case default
    stop 'Используется GETARG. Выберите: rk, ae или ai'
end select

end program diffurmodule lead
use mprecision

contains

subroutine leadfun(M,X,n)
! *** Процедура строит матрицу для решения методом Гаусса, но на каждом шаге ставит
! *** наибольший по модулю элемент ведущим, чтобы избегать деления на близкий к нулю элемент
implicit none
character(6) :: choice='lead'
real(mp), dimension(1:n+1,n) :: M
real(mp), dimension(1:n) :: X
integer :: i, j, k, n
real(mp), dimension(n+1) :: Help ! Вспомогательный массив. Используется для временного сохранения в него
                               ! массива или элемента при нужде в перестановке по принципу: a<->b: c=b, b=a, a=c
integer, dimension(2,n) :: Trans ! Этот массив содержит в каждой строке соответственно номера столбцов и
                                 ! строк, которые поменялись ради выбора большого по модулю ведущего элемента
! ------------------------------------------------
do k=1,n-1 ! Тот же цикл, что и в методе Гаусса, но с перестановкой строк и столбцов
    if ( abs( maxval(M(k:n,k:n)) ) > abs( minval(M(k:n,k:n)) ) ) then ! Происходит выбор наибольшего по модулю
	Trans(1:2,k)=(k-1)+maxloc(M(k:n,k:n))                         ! элемента, и его "координаты" записываются...
    else
	Trans(1:2,k)=(k-1)+minloc(M(k:n,k:n))                         ! ... в массив Trans в k-тую строку
    endif
!-------------------------------------------------
    Help(1:n+1)=M(1:n+1,Trans(2,k)) ! Все, что происходит в этом блоке, - это
    M(1:n+1,Trans(2,k))=M(1:n+1,k)  ! перестановка двух строк для получения большого
    M(1:n+1,k)=Help(1:n+1)          ! ведущего элемента в k-той (текущей) строке

    Help(1:n)=M(Trans(1,k),1:n)     ! ----"---- аналогично, меняются столбцы
    M(Trans(1,k),1:n)=M(k,1:n)
    M(k,1:n)=Help(1:n)
!-------------------------------------------------
    forall (j=k:n+1) M(j,k)=M(j,k)/M(k,k) ! Оба "forall" строят матрицу с переставленными элементами "по Гауссу"
    forall (i=k+1:n, j=k:n+1) M(j,i)=M(j,i)-M(k,i)*M(j,k)
enddo
M(n:n+1,n)=M(n:n+1,n)/M(n,n) ! (n,n)-ый элемент не нуждался в перестановке и по известным причинам не попал в цикл
!-------------------------------------------------
call solution(choice,M,X,n)
!-------------------------------------------------
! После выдачи процедурой solution массива из иксов, нужно его привести в порядок, ведь мы делали перестановки
do k=n-1,1,-1
    Help(k)=X(Trans(1,k))
    X(Trans(1,k))=X(k)
    X(k)=Help(k)
enddo

end subroutine leadfun

subroutine solution(choice,M,X,n)
! *** Процедура высчитывает массив решений, используя уже преобразованную расширенную матрицу
implicit none
integer :: i, n
real(mp), dimension(1:n+1,n) :: M
real(mp), dimension(1:n) :: X
character(6) :: choice ! Процедура, вызывающая solution, даст о себе знать, благодаря переменной "choice"
!-------------------------------------------------
if (choice /= 'jordan') then ! Только для метода Жордана счет иксов ведется по-другому
    do i=n,1,-1
	X(i)=M(n+1,i)-dot_product(M(i+1:n,i),X(i+1:n))
    enddo
else
    do i=1,n
	X(i)=M(n+1,i)
    enddo
endif

end subroutine solution

end module leadmodule mprecision

integer, parameter :: mp=4


end module mprecisionmodule newtonmethod
use mprecision
use lead

contains

subroutine newton(X0,nummax,X,f)
! *** Процедура контролирует получение вектора решения на каком-то шаге итераций
implicit none
real(mp), dimension(1:), intent(in) :: X0 ! X0 - начальное приближение
real(mp), dimension(1:size(X0)), intent(out) :: X
real(mp), dimension(1:size(X0)) :: Xnew ! Xnew - вектор X, получаемый при новом шаге итераций
real(mp) :: eps=0.1_mp**4
integer, intent(in) :: nummax
integer :: i, n
interface
function F(X)
use mprecision
real(mp), dimension(1:), intent(in) :: X
real(mp), dimension(1:size(X)) :: F
end function F
end interface

n=size(X0)
!---------------------------------------
X=X0; i=nummax; Xnew=X0+1.0_mp ! Число выбрано случайно для устранения возможного совпадения с X0
do while (sum(abs(X-Xnew))>eps .and. i>=1)
    X=Xnew
    call solve(X,Xnew,F)
    i=i-1
enddo
X=Xnew ! Здесь X присваивает значение найденного решения


end subroutine newton

subroutine solve(X,Xnew,F)
! *** Процедура получает новый вектор решений по методу Ньютона (с помощью итераций)
implicit none
real(mp), dimension(1:), intent(in) :: X
real(mp), dimension(1:size(X)), intent(out) :: Xnew
real(mp), dimension(1:size(X),1:size(X)) :: df ! df - матрица Якоби функции f
real(mp), dimension(1:size(X)+1,1:size(X)) :: M ! M - расширенная матрица системы f+sum(df*(Xnewk-Xk))=0
integer :: i, n
interface
function F(X)
use mprecision
real(mp), dimension(1:), intent(in) :: X
real(mp), dimension(1:size(X)) :: F
end function F
end interface

n=size(X)
!---------------------------------------
call yakobmatrix(X,df,F)
M(n+1,1:n)=-F(X)
M(1:n,1:n)=df(1:n,1:n)
call leadfun(M,Xnew,n)
Xnew=Xnew+X ! (Так как при решении системы, был получен вектор Xnew-X)


end subroutine solve

subroutine yakobmatrix(X0,df,F)
! *** Процедура создает матрицу Якоби для f(x) в точке X0
implicit none
real(mp), dimension(1:), intent(in) :: X0
real(mp), dimension(1:size(X0),1:size(X0)), intent(out) :: df
real(mp), dimension(1:size(X0)) :: X
real(mp) :: eps=0.1_mp**3
integer :: i, n
interface
function F(X)
use mprecision
real(mp), dimension(1:), intent(in) :: X
real(mp), dimension(1:size(X)) :: F
end function F
end interface

n=size(X0)
!---------------------------------------
do i=1,n
    X=X0
    X(i)=X0(i)+eps
    df(i,1:n)=(F(X)-F(X0))/eps
enddo

end subroutine yakobmatrix

end module newtonmethodmodule rungekut
use ffunction

contains

subroutine rk4(X0,t,X)
! *** Процедура из вектора X0(t) находит вектор X(t+h)
implicit none
real(mp), dimension(1:), intent(in) :: X0
real(mp), intent(in) :: t
real(mp), dimension(1:size(X0)), intent(out) :: X
real(mp), dimension(1:size(X0)) :: K1, K2, K3, K4
!---------------------------------------
K1=h*f(t,X0)
K2=h*f(t+h/2,X0+K1/2)
K3=h*f(t+h/2,X0+K2/2)
K4=h*f(t+h,X0+K3)

X=X0+1.0_mp/6*(K1+2.0_mp*K2+2.0_mp*K3+K4)

end subroutine rk4

end module rungekut
