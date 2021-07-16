(* A little helper function to render the counter value.  Notice how
 * the integer value (n) is wrapped in two kinds of parentheses.  This
 * is because n is a literal from the Ur programming laguage -- it is not
 * an xml value.  We use curly braces {} within an xml literal to indicate
 * that we are beginning an expression that should be evaluated and will
 * generate an xml literal.  The square brackets [] convert Ur literals
 * directly into xml literals.  This entire process is known as quasi-quoting.
 *)
fun renderCounter n : xbody =
    <xml><span>{[n]}</span></xml>

(* little higher order helper function for updating a source's contents *)
fun updateSource [a] (s : source a) (f : a -> a) : transaction unit =
    n <- get s;
    set s (f n)
                                
(* Workhorse function, which [main] will call
 * 
 * This is the function that renders the entire page.  The top half
 * is the counter using server-side calls.  The bottom half uses client
 * side javascript calls to dynamically update its counter without
 * round-tripping to the server.
 * 
 * When you run the application, see how the client side counter gets
 * reset when you make a server-side call; while the servier-side counter
 * remains intact when the client-side functions are invoked.
 *)
fun renderCounterPage n : transaction page =
    (* start the client counter at whatever value the server
     * counter is set to.
     *)
    clientCounter <- source n;
    return
        <xml><body>
          <!-- This section of the web page is updated by following links
               which make a request back to the server and re-render the
               page in its entirety.
          -->
          <h1>This counter goes server side for update</h1>
          Current server-side counter: {renderCounter n}<br/>
          <div><a link={renderCounterPage (n + 1)}>Server Inc</a></div>
          <div><a link={renderCounterPage (n - 1)}>Server Dec</a></div>
          <!-- Here, counter updates are handled via javascript calls which never leave the page.
               This means that we can make local changes to the DOM. -->
          <h1>This counter updates locally</h1>
          <div>Current client side value:
            <!-- dyn is a "pseudo-tag" which marks a place where updates will happen based off of a signal.
                 Signals are attached to sources and when the source value is updated, the signal is triggered,
                 re-rendering the DOM at the location of the dyn tag with whatever xml contents are produced
                 by the function registered with the signal. -->
            <dyn signal={n <- signal clientCounter; return (renderCounter n)}/>
            <div>
              <button onclick={fn _ => updateSource clientCounter (fn i => i + 1)}>Inc</button>
              <button onclick={fn _ => updateSource clientCounter (fn i => i - 1)}>Dec</button>
            </div>
          </div>
        </body></xml>

(* Entry point to the application -- we start the counters at 0 *)
fun main () =
    renderCounterPage 0

(*
 * Exercises
 * 
 * ***************************************************************************************
 * ***************************************************************************************
 * 
 * 1. Let's make the client-side counter's increment value configurable.  Since this our 
 *    first foray into programming in Ur/Web, let's do it in stages.
 *
 * 1a.  Add a dyn/source/signal combination which holds the increment-by value.  You should
 *      be able to mostly copy from the /clientCounter/ examples.  Make sure to add buttons
 *      which increase/decrease the increment-by value.  Be sure to test out your implementation!
 * 
 * 1b.  Now, we need to hook our new source into the actual counter increment/decrement buttons.
 *      How can you do this?  Hint:  one way could involve adding an argument to the [updateSource] 
 *      function....
 * 
 * ***************************************************************************************
 * 
 * 2. A small detail, which we really haven't discussed at all is the construction of urls.
 *    Ur/Web tries to construct pretty (or at least, human readable) urls for its applications.
 *    However, you may not agree with its choices, particularly because it has to make some
 *    conservative choices about the urls are constructed.  For example, in our application 
 *    here, you may have noticed that you had to navigate to /Counter/main in order to get
 *    to the top-level application.  You may be able to guess how that name was constructed:
 *    Ur/Web appended the filename (module name) with the function name and voila!  The 
 *    counter application only has a single module, so that initial /Counter/ is a bit
 *    unnecessary.  The good news is that we can rewrite urls!  Page 8 of the reference 
 *    manual has the details, but you can just follow along and learn by example below.
 *
 * 2a. Let's start by getting rid of that pesky /Counter preamble.  Open up counter.urp, and
 *     at the beginning type in:  "rewrite url Counter/*".  Make sure that there is a blank
 *     line between your new line and the existing line that reads: counter.
 * 
 *     Now, browse to http://localhost:8080/main -- pretty cool!  Now all urls who start with
 *     that nonsense preamble Counter/ will be rewritten with whatever follows it!
 * 
 * 2b. We still have an unpleasantry, if you are into url aesthetics.  The /main url now
 *     effectively redirects to /renderCounterPage/0, and subsequent calls to the increment/decrement
 *     functions update the "0" with the appropriate number.  We would like some uniformity
 *     to these urls; however, only the first rule that matches fires.  So, maybe change the
 *     rule input in 2a to "rewrite url Counter/main counter".  Now http://localhost:8080/counter
 *     is the top level url, but any clicks on the increment/decrement urls go to
 *     /Counter/renderCounterPage/<some number>.  What rule can you add to fix this?
 * 
 * There are all kinds of rewrites you can do in the .urp files.  When you start the blog
 * exercises, you may want to examine blog.urp to see some more examples!
 * 
 *)
