# Ur/Web Exercises for Beaverworks Summer Institute Cyber Course

In this repository, you will find a couple of example Ur/Web projects, 
along with comments within them for student exercises.  We suggest that
you begin with the _counter_ project, as it is a smaller example which
will get you used to the Ur/Web programming model.

The provided `Makefile` includes all of the necessary compilation instructions.
We suggest that you look over the Makefile to get an idea of what is going on.
Embedded within the comments of each project are ideas for exercises you can
perform yourself.  We encourage you to do the suggested exercises, and also to
experiment with the applications -- make them your own!

A word of caution.  Particularly when learning Ur/Web, we find that the compiler
can produce in-decipherable error messages.  We find that it is best to get
yourself into a development rhythm where you make small changes, compile, and
test that the application behaves as expected.  Sometimes, writing down the
types within your functions will help as well (rather than relying too much on
type inference).  If your changes are small enough, you will always be able to
easily get back to a known good state and try again!

## Counter Project

In order to compile and run the counter application, at a shell type:

```bash
make counter-run
```
Once the application is running, open a web browser and browse to
[http://localhost:8080/Counter/main](http://localhost:8080/Counter/main).
You should experiment with the differences in behavior when incrementing and
decrementing the server counter vs. the client-side counter.

## Blog Project

You can compile and run the blog project via:

```bash
make blog-run
```

The application can then be found at [http://localhost:8080/blog](http://localhost:8080/blog).


# Acknowledgements

The ideas in this repo were drawn from a few sources.  The counter example was derived from 
the [Ur/Web demo of the same name](http://www.impredicative.com/ur/demo/).  I learned how to
do the blog from the [excellent tutorial by Gian Perrone](http://www.expdev.net/urtutorial/)
though I don't believe much code here is the same anymore, except for perhaps some of the
auth functions.
