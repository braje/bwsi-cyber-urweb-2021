(*
 * Let's start with a very simple data model.  Only logged in users can post new content, but anyone
 * can comment on existing posts.  Logged in users can edit their own created content (posts and comments).
 *)
table user : { Id : int, Username : string, Password : string }
                 PRIMARY KEY Id

table entry : { Id : int, Title : string, Created : time, Author : int, Body : string }
                  PRIMARY KEY Id
    , CONSTRAINT Author FOREIGN KEY Author REFERENCES user(Id)

table comment : {Id : int, Entry : int, Created : time, Author : option int, Body : string }
	                  PRIMARY KEY Id
	  , CONSTRAINT Entry FOREIGN KEY Entry REFERENCES entry(Id)
	  , CONSTRAINT Author FOREIGN KEY Author REFERENCES user(Id)

sequence userS
sequence entryS
sequence commentS

(*
 * Here, we are opening up the contents of two other modules so that we can access
 * their names via unqualified access.  In this case, our modules define different
 * css styles for controlling layout of our blog.  We need to do this because Ur/Web
 * requires that css classes are explicitly declared and blessed by the application 
 * developer -- another safety consideration!
 *)
open Bootstrap3
open Css

(*
 * Here, we define a new type in a different way.  What we are doing is effectively
 * giving a name to what is called a record type.  Records have a variety of named
 * fields which you can access kind of like your favorite object oriented programming
 * language.  This particular type includes the necessary /source/s for page updates.
 *)
type sources = { 
     Detail : source xbody,
     RightPanel : source xbody
}

(* 
 * We have a standard header for all of our pages.  Pull out into a simple 
 * function we can use to append to a body content. 
 *)
fun addHead (bdy : page) =
    (<xml>
      <head>
      (* <meta charset="utf-8"/> *)
      <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no"/>
      <title>Bloggering</title>
      <link rel="stylesheet" href="/css/bootstrap3.4.min.css" />
      <link rel="stylesheet" type="text/css" href="/css/myblog.css"/>
      <link rel="shortcut icon" href="https://material.io/favicon.ico"/>
      </head>
      { bdy }
    </xml>)

(*
 * Authentication
 * *******************************************************************************
 * Here, we implement an authentication module, hiding most of its signature, 
 * right inline our main source file.  Better practice may be to split across
 * the two auth.urs and auth.ur files, but we both want this project to be easier
 * to edit and to show another way to perform encapsulation.  Only members within
 * the signature of the module are exported, so anything else remains an internal
 * implementation detail.  This is a great way to encapsulate hidden parts of your
 * application.  Here, for example, we hide the cookie implementation and force
 * developers to manage cookie state through the login/logout interface.
 *)
structure Auth : sig
    val login : transaction page -> transaction page
    val logout : transaction page -> transaction page
    val getCurrentUser : transaction (option (int * string))
end = struct

    (* no function outside of the ones in this module can access the cookie! *)
    cookie userSession : { UserId : int, Username : string, Password : string }

    (* Helper function which handles the authentication check as well as cookie
     * management.
     * 
     * This is our first use of a database query.  Note how SQL (like XML) is
     * embedded directly within the language.  Note also the use of quasiquotes
     * in handling the "variables" to the query.  Ur/Web will not allow you to 
     * build SQL statement through string concatenation, thus essentially 
     * eliminating the possibility of SQL injection attacks.
     * 
     * The query function [oneOrNoRows1] returns an option type, depending on
     * whether a row was found in the database.
     *)
    fun tryAuthenticate username password : transaction bool =
        re' <- oneOrNoRows1(SELECT user.Id
                            FROM user 
                            WHERE user.Username = {[username]} 
                              AND user.Password = {[password]});
        case re' of
            None => return False
          | Some re => 
            setCookie userSession 
                      {Value = { UserId = re.Id, Username = username, Password = password}, 
                       Expires = None,
                       Secure = True};
            return True

    (* Attempt to log in, if you fail, go to error page, otherwise proceed to the page passed in
     * as an argument *)
    fun ifAuthenticated [a] (p : transaction a) (username : string) (password : string) : transaction a =
        authenticated <- tryAuthenticate username password;
        case authenticated of
            False => error <xml>Invalid Login</xml>
          | True  => p

    (* Read the login state of the user from the cookie.  A new bit of syntax here:
     * val is kind of like fun, except it can take no arguments.  It is kind of like if you 
     * defined a function "fun foo () = ..." with the difference that in the foo case, you have
     * to invoke it by calling foo(); whereas you can just directly call getCurrentUser *)
    val getCurrentUser : transaction (option (int * string)) =
        loggedIn <- getCookie userSession;
        return (case loggedIn of None => None
                               | Some u => Some (u.UserId, u.Username))

    (* Clear the cookie and proceed to the 'next' page *)
    fun logout (next : transaction page) : transaction page =
        clearCookie userSession;
        next

    (* Handler for the form post.  Basically just unpacks the record produced by the form submit
     * and forwards onto [ifAuthenticated] *)
    fun loginHandler (next : transaction page) form_record : transaction page = 
        ifAuthenticated next form_record.Username form_record.Password

    (* Generate a login form.  The interesting thing to note here is how the form fields get bound
     * and passed into the handler that is registered as an action for the form.  Two notes here:
     *  1) Form fields are registered with {#<field name>} and "field name" is the name that is bound
     *     within the record passed into the handler 
     *  2) Note what we did here with the form handler -- it has an extra argument that is not part of
     *     the form submission.  What we have done is pass on additional information needed by the
     *     handler, but not provided by the user, by _partially applying_ the function.  This is a
     *     very common technique in functional programming.  
     *)
    fun login (next : transaction page) : transaction page =
        return
            ( addHead
                  <xml>
                    <body>
                      <main class="container" style="margin-top: 5em;">
                        <div class="col_md_8">
                          <form>
                            <div class="form-group">
                              <label>Username</label>
                              <textbox{#Username} class="form-control" />
                            </div>
                            <div class="form-group">
                              <label>Password</label>
                              <password{#Password} class="form-control" />
                            </div>
					                  <submit class="btn btn-primary" value="Login" action={loginHandler next}/>
                          </form>
                        </div>
                      </main>
                    </body>
                  </xml>)
end

(* Open up the Auth module, so we can use its public methods without namespacing them. *)
open Auth

(*
 * Password update function for use in exercise 2.  Returns True if there was an update, False otherwise
 *)
fun updatePassword (username : string) (new_password : string) (old_password : string) : transaction bool =
    hashNew <- Bcrypt.hash new_password;
    hashOld <- Bcrypt.hash old_password;
    userId <- oneOrNoRows1 (SELECT user.Id
                            FROM user
                            WHERE user.Username = {[username]}
                              AND user.Password = {[if old_password = "" then "" else hashOld]});
    case userId of
        None     => return False
      | Some uid => 
        dml (UPDATE user
             SET Password = {[hashNew]}
             WHERE Id = {[uid.Id]});
        return True

(* 
 * Simple datatype for controlling which part of the view we update.  
 *)
datatype viewUpdate =
         BlogDetail of int
       | AllPostsList
       | NewBlogPost

type viewUpdater = viewUpdate -> transaction unit
         
(* Build the html for the menu at the top of the page.  We pass in the reference to the 
 * top level page of our blog, so that login/logout know where to proceed after performing
 * their functions, and so that we can keep a nice reference back to home at the top of the
 * page.  Alternatively, we could have used the string /blog or something, but then we would
 * have to register that as a safe url in our .urp file (allow url /blog) and also do some
 * conversions from string to url in the login/logout functions.
 *)
fun menuView (vUpd : viewUpdater) (top : transaction page) (user : option (int * string)) : xbody =
    <xml>
      <nav class="navbar navbar_inverse">
        <ul class="bs3_nav navbar_nav">
          <li><a link={top}>Home</a></li>
          { case user of
                None   => <xml/>
                | Some _ =>
                <xml>
                  <li><a onclick={fn _ => vUpd NewBlogPost }>New Post</a></li>
                </xml>
                }
          </ul>
          { case user of
                None =>
                <xml>
                  <ul class="bs3_nav navbar_nav navbar_right">
                    <li><a link={login top}>Login</a></li>
                  </ul>
                </xml>
              | Some (_,u) =>
                <xml>
                  <p class="navbar-text navbar-right">Signed in as {[u]}
                    <a link={logout top}>Logout</a>
                  </p>
                </xml>
          }
        </nav>
      </xml>

(*
 * Simple query to lookup a blog entry by id.  Pulled out into a separate
 * function because it will be used in an rpc call and Ur/Web requires all
 * rpc calls to be invoked on named functions.
 *)
fun detailQuery (i : int) =
    oneOrNoRows1 (SELECT * FROM entry WHERE entry.Id = {[i]})

(* 
 * This function generates the html for a detailed view of a blog post, after 
 * making an rpc call back to the server asking for the data.  Because of the
 * rpc call, this code is expected to run on the client.
 *)               
fun detailView (i:int) : transaction xbody = 
    res <- rpc (detailQuery i);
    return
        (case res of
             None =>
             <xml>
               <h1>Entry not found</h1>
             </xml>
           | Some r => 
             <xml>
               <div class="panel panel_default">
                 <div class="panel_heading">
                   <h1 class="panel_title blogEntryTitle">{[r.Title]}</h1>
                 </div>
                 <div class="panel-body">
                   {[r.Body]}
                 </div>
               </div>
             </xml>
        )

(*
 * Query for summary data on all blog posts in the database.  Again,
 * separated out so it can be used in an rpc call.
 *)
val allPostsListQuery =
    queryL1 (SELECT entry.Id,entry.Title FROM entry)
    
(*
 * Retrieve and then render a summary list of all blog posts
 *)
fun allPostsListView (vUpd : viewUpdater) : transaction xbody =
    rows <- rpc allPostsListQuery;
    return (List.mapX 
            (fn row =>
                <xml>
                  <div>
                    <a onclick={fn _ => vUpd (BlogDetail row.Id) }>{[row.Title]}</a>
                  </div>
                </xml>
            )
            rows)

(*
 * Helper function for inserting a new blog post into the database.  You will note
 * a couple of new things here:
 *  1) the [dml] function is the wrapper for doing inserts
 *  2) each table has a sequence which stores the next available ID -- the first
 *     operation here is to get that new id so that we can perform the insert
 *)
fun submitNewBlogPost (bp : { Title : string, Body : string }) : transaction int =
    curUser <- getCurrentUser;
    case curUser of
        None => error <xml>Not Logged In</xml>
      | Some (uid,_) =>
        (* grab the next id for the entry table *)
        blogId  <- nextval entryS;
        dml ( INSERT INTO entry ( Id, Title, Created, Author, Body)
              VALUES ( {[blogId]}, {[bp.Title]}, CURRENT_TIMESTAMP, {[uid]}, {[bp.Body]} )
            );
        (* return the new identifier so we can display our new blog post in
         * the detail view *)
        return blogId

(*
 * Here's our first example of performing a form-like submission via an ajax call.
 * We start by creating /source/s for each of the fields, and attaching those
 * sources to the appropriate html elements.  We then register an onclick handler
 * which reads the values from those sources, and forwards onto the relevant
 * handling function with an rpc call.
 *)
fun newBlogPostView (vUpd : viewUpdater) : transaction xbody =
    blogTitle <- source "";
    blogBody  <- source "";
    return
        <xml>
          <div class="form-group">
            <label>Title: </label>
            <ctextbox source={blogTitle} class="form-control"/>
          </div>
          <div class="form-group">
            <label>Post: </label>
            <ctextarea source={blogBody} class="form-control"/>
          </div>
          <button class="btn btn-primary"
                  onclick={fn _ =>
                              title <- get blogTitle;
                              body  <- get blogBody;
                              bid   <- rpc (submitNewBlogPost { Title = title, Body= body });
                              vUpd (BlogDetail bid); vUpd AllPostsList}>Submit</button>
          </xml>
    
(*
 * General dispatch function that takes in "viewUpdate" values and dispatches to the appropriate
 * handling function.
 *)    
fun updateView (pageSources : sources) (v : viewUpdate) : transaction unit =
    case v of
        BlogDetail bid => content <- detailView bid; set pageSources.Detail content
      | AllPostsList   => content <- allPostsListView (updateView pageSources); set pageSources.RightPanel content
      | NewBlogPost    => content <- newBlogPostView (updateView pageSources); set pageSources.Detail content

(*
 * This is the main entry point to our blog.
 *)
fun blog () : transaction page =
    detailSource <- source <xml/>;
    listSource <- source <xml/>;
    pageSources <- return { Detail = detailSource, RightPanel = listSource };
    user        <- getCurrentUser;

    return
        (addHead
             <xml>
               <body onload = { updateView pageSources (BlogDetail 1); updateView pageSources AllPostsList }>
                 { menuView (updateView pageSources) ( blog() ) user }
                 <main class="container">
                   <div class="col_md_8 outline">
                     <dyn signal={ signal detailSource }/>
                   </div>
                   <div class="col_md_4 outline">
                     <h1>Blog Posts</h1>
                     <dyn signal={ signal listSource }/>
                   </div>
                 </main>
               </body>
             </xml>)

(*
 * Exercises
 * 
 * ***************************************************************************************
 * ***************************************************************************************
 * 
 * 1. Our first exercise, to get warmed up writing database queries is going to be to fix
 *    a small shortcut we took. You will notice that we have hardcoded a blog detail id
 *    in the onload handler in the body tag of our top-level [blog] function.   
 * 
 * 1a. Start by writing the sql query function.  You should use [oneRowE1] to
 *     make the call.  Hint: there are MIN and MAX functions in SQL, so SELECT MAX( Id ) ...
 *     selects the maximum id from whatever table you specify. Look at [tryAuthenticate]
 *     for a similar query (that doesn't use MAX).
 * 
 * 1b. Hook up your new function in [blog].  Remember, this function runs server-side, so
 *     you do not need to make an rpc call.  Check that you get the expected result when
 *     you load up the application.
 * 
 * ***************************************************************************************
 * 
 * 2. Sigh.  We have created a webapp with a default user!  Not only that, but we are not
 *    following even the basic level of security and hashing passwords stored in the 
 *    database.  I found a hashing library, and included it into the build, so you
 *    can fix this!  Look at https://github.com/steinuil/urweb-bcrypt for examples
 *    of how to use the library.
 *
 * 2a. In order to add a password for the admin user, you need a change password form.
 *     Since there were no other examples on how to perform an UPDATE, I have implemented
 *     the function for you.  Review it [updatePassword], then thing closely about a
 *     terrible mistake we have made with our data model.  You may want to update
 *     one of the tables with a new constraint.  Check out the Ur/Web demos (constraint,
 *     specifically) to figure out what to do and make the change.
 * 
 * 2b. Create the change password form.  You may want to crib from the login form.
 *     Create a "change password" menu item, and link it up to your change password
 *     form.  Again, this should all look very similar to the login infrastructure.
 *     Don't worry about hashing yet!
 *
 * 2c. Okay, if you followed the login example, this works fine, but doesn't do exactly
 *     what you want.  You passed in a "next page" so that you can go on if you 
 *     successfully change the password, but what do you do on a failure?  You can
 *     produce an error page, but how about we just redirect back to the changePassword
 *     page instead?  Better people than us would indicate that there was some kind of
 *     failure, but, again, in the name of simplicity, we will not worry about that.  One
 *     Thing you have to know is a new piece of syntax:  when you have two functions that
 *     recursively call each other, you need to declare them next to each other and the
 *     second one should use the keyword 'and' instead of 'fun'.  So, in this case, you
 *     would have:  
 *       fun changePasswordHandler ... 
 *       and changePasswordForm ...
 *     with the difference being that changePasswordHandler can now call changePasswordForm.
 * 
 * 2d. To round this out we need to do two things.  We need to implement the
 *     hashing-based password checking and storage.  And, we need to special-case the
 *     login to redirect to the change password form if the password is empty (an alternative
 *     design could be to add a flag for the user table which forces password reset, but we
 *     are keeping things simple right now).
 * 
 * 2e. If you want, you can also go ahead and make a create user page.  This should once
 *     again be very similar to the change password form you have already created, but
 *     will give you practice coding up these forms.
 * 
 * ***************************************************************************************
 * 
 * 3. Comments are an essential(?) part of a blogging site.  Let's add this feature!  Unlike
 *    the user and password administration pages up above, we will do this via client-side
 *    updates -- like a real, modern web site!
 * 
 * 3a. If we are going to author comments, we should probably display them as well.  There are
 *     already some pre-loaded comments for the "Test entry 1" blog post.  Write the appropriate
 *     comment retrieval database function, append appropriate view code to the blog post
 *     detail view, and render any existing comments.  You can test by looking at "Test Entry 1".
 * 
 * 3b. You can now add an "Comment on this post" button at the bottom of the page.  Its
 *     onclick action should build the necessary input fields for writing a new comment.
 *     Remember, this will be a client-side ajax request, so don't wrap your input elements
 *     in a form tag -- instead, look at how blog post creation is done.  Hook everything
 *     up and start commenting!  Comments from logged in users should include a reference to
 *     their userId.
 * 
 * ***************************************************************************************
 * 
 * 4. Choose your own adventure...  You are free to create any features you may like at this
 *    point.  Some ideas:  
 * 
 *      * Update user table to have a forcePasswordChange field, default password management
 *      * View my posts
 *      * View my comments
 *      * Post/comment editing/deleting
 *      * Adding next post / previous post links
 * 
 * ***************************************************************************************
 * 
 *)
