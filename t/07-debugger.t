use Test::More;

BEGIN {
  $ENV{PERLDB_OPTS} = 'NonStop';
}

BEGIN {

#line 1
#!/usr/bin/perl -d
#line 10

}

{
    package Foo;

    BEGIN { *baz = sub { 42 } }
    sub foo { 22 }

    use namespace::clean;

    sub bar {
        ::is(baz(), 42);
        ::is(foo(), 22);
    }
}

ok( !Foo->can("foo"), "foo cleaned up" );
ok( !Foo->can("baz"), "baz cleaned up" );

Foo->bar();

done_testing;
