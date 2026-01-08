load("http.star", "http")
load("render.star", "render")
load("schema.star", "schema")

def main(config):
    # --- Configuration ---
    movie_name = config.get("movie", "The Matrix")
    api_key = config.get("apikey")
    view_mode = config.get("view_mode", "cycle")

    # 1. Check for API Key
    if not api_key:
        return render.Root(child = render.Text("Enter API Key"))

    # 2. Prepare Name
    movie_name = movie_name.title()

    # 3. Fetch Data Once
    url = "https://www.omdbapi.com/?apikey={}&t={}".format(api_key, movie_name.replace(" ", "+"))
    res = http.get(url, ttl_seconds = 3600)  # Cache for 1 hour

    if res.status_code != 200:
        return render.Root(child = render.Text("Err: %d" % res.status_code))

    data = res.json()
    if data.get("Response") == "False":
        return render.Root(child = render.WrappedText(data.get("Error", "Movie Not Found")))

    # --- View Selection Logic ---

    if view_mode == "marquee":
        return render_marquee(data)
    elif view_mode == "details":
        return render_details(data)
    elif view_mode == "poster":
        # Check poster availability first
        if not data.get("Poster") or data.get("Poster") == "N/A":
            return render.Root(child = render.Text("No Poster"))
        return render_poster(data)
    elif view_mode == "ratings":
        return render_ratings(data)
    else:
        # "cycle" mode: We create a sequence of animations
        # However, Pixlet does not easily support sequencing completely different Root objects
        # (like scrolling marquees vs static images) into one seamless loop via `render.Animation`
        # if they have vastly different structures.
        # But we can try to wrap them in an Animation child list.
        # Note: Heavy marquees in Animation children can sometimes be tricky.

        # A safer "Cycle" implementation for simple config cycling is to return one based on time,
        # but since we want them to flash through on the screen, let's try combining them.

        # We will render each component into a frame and show them for a few seconds each.

        # Frames:
        # 1. Marquee (Run for ~4 seconds)
        # 2. Poster (Run for ~4 seconds)
        # 3. Details (Run for ~4 seconds)
        # 4. Ratings (Run for ~4 seconds)

        # Since 'render_marquee' itself returns a Root with an Animation, extracting just the widget is better.

        return render.Root(
            delay = 4000,  # Default delay for static frames (poster/ratings/details)
            child = render.Animation(
                children = [
                    # Frame 1: Marquee (Note: Marquee has its own internal animation, so this might just show one frame of it if not careful.
                    # But the Marquee function actually returns an Animation widget itself. We can't nest Animation inside Animation frames easily in a linear timeline without complex delays.)

                    # SIMPLIFIED CYCLE STRATEGY:
                    # Since true sequencing of complex animations is hard, we will cycle based on user preference or just stick to one.
                    # As requested "combine into a single app", usually implies configuration choice.
                    # If "Cycle" is hard requirement, we usually use `render.Sequence` if available (not standard) or just time-based logic.

                    # For now, let's just create the frames.
                    # Note: Putting 'render.Marquee' inside 'render.Animation' frames works, but the 'delay' of the parent Animation controls who long that frame stays.

                    # Marquee View (This one is special because it flashes)
                    # We'll just show the static "ON" state of the marquee for the cycle to keep it simple and readable
                    marquee_widget(data, simple = True),

                    # Poster View
                    poster_widget(data),

                    # Details View
                    details_widget(data),

                    # Ratings View
                    ratings_widget(data),
                ],
            ),
        )

# --- Render Functions (Return Root) ---

def render_marquee(data):
    return render.Root(
        delay = 500,
        child = marquee_widget(data, simple = False),
    )

def render_details(data):
    return render.Root(child = details_widget(data))

def render_poster(data):
    return render.Root(child = poster_widget(data))

def render_ratings(data):
    return render.Root(child = ratings_widget(data))

# --- Widget Functions (Return Widget) ---

def marquee_widget(data, simple = False):
    title = data.get("Title", "Unknown")

    def format_title_text(t):
        t = t.upper()
        l = len(t)
        if l <= 10:
            font = "6x13"
        elif l <= 30:
            font = "tb-8"
        else:
            font = "tom-thumb"
        return render.WrappedText(content = t, font = font, width = 64, color = "#ff0", align = "center", linespacing = 0)

    # Helper for the blinking dots
    def get_dots(offset):
        children = []
        for i in range(64):
            color = "#fff" if (i % 2) == offset else "#000"
            children.append(render.Box(width = 1, height = 1, color = color))
        return children

    def build_frame(offset):
        # We need to construct the full dotted border manually
        # Top
        top_row = render.Row(children = get_dots(offset))

        # Bottom
        bottom_row = render.Row(children = get_dots(offset))

        # Sides (7px high)
        side_dots = render.Column(children = [render.Box(width = 1, height = 1, color = "#fff" if (i % 2) == offset else "#000") for i in range(7)])

        return render.Column(
            children = [
                render.Column(
                    children = [
                        top_row,
                        render.Row(
                            children = [
                                side_dots,
                                render.Box(
                                    width = 62,
                                    height = 7,
                                    child = render.Padding(
                                        pad = (0, 1, 0, 0),
                                        child = render.Text("NOW SHOWING", font = "tom-thumb", color = "#fff"),
                                    ),
                                ),
                                side_dots,
                            ],
                        ),
                        bottom_row,
                    ],
                ),
                render.Box(
                    width = 64,
                    height = 23,
                    child = render.Column(
                        expanded = True,
                        main_align = "center",
                        cross_align = "center",
                        children = [format_title_text(title)],
                    ),
                ),
            ],
        )

    if simple:
        # Just return one static frame (offset 0)
        return build_frame(0)
    else:
        # Return the flashing animation
        return render.Animation(
            children = [
                build_frame(0),
                build_frame(1),
            ],
        )

def details_widget(data):
    runtime = data.get("Runtime", "N/A")
    year = data.get("Year", "N/A")
    genre = data.get("Genre", "N/A")

    return render.Column(
        main_align = "start",
        expanded = True,
        children = [
            render.Box(height = 1),
            render.Row(
                main_align = "space_between",
                expanded = True,
                children = [
                    render.Text(year, font = "tom-thumb", color = "#ff0"),
                    render.Text(runtime, font = "tom-thumb", color = "#0f0"),
                ],
            ),
            render.Box(height = 2),
            render.Box(
                width = 64,
                height = 23,
                child = render.Column(
                    expanded = True,
                    main_align = "center",
                    children = [
                        render.WrappedText(content = genre, width = 64, font = "tom-thumb", color = "#aaa", align = "center"),
                    ],
                ),
            ),
        ],
    )

def poster_widget(data):
    poster_url = data.get("Poster")
    if not poster_url or poster_url == "N/A":
        return render.Text("No Poster")

    poster_res = http.get(poster_url, ttl_seconds = 3600)
    if poster_res.status_code != 200:
        return render.Text("Img Err")

    return render.Box(
        width = 64,
        height = 32,
        child = render.Marquee(
            width = 64,
            height = 32,
            scroll_direction = "vertical",
            delay = 30,
            child = render.Image(src = poster_res.body(), width = 64),
        ),
    )

def ratings_widget(data):
    ratings = data.get("Ratings", [])
    imdb, rt, meta = "N/A", "N/A", "N/A"
    for r in ratings:
        s = r.get("Source")
        v = r.get("Value")
        if s == "Internet Movie Database":
            imdb = v
        elif s == "Rotten Tomatoes":
            rt = v
        elif s == "Metacritic":
            meta = v.split("/")[0]

    def parse_score(val):
        if val == "N/A":
            return 0
        if "%" in val:
            return int(val.replace("%", ""))
        if "/" in val:
            return float(val.split("/")[0]) / float(val.split("/")[1]) * 100
        if val.isdigit():
            return int(val)
        return 0

    return render.Padding(
        pad = (2, 0, 2, 0),
        child = render.Column(
            main_align = "space_evenly",
            expanded = True,
            children = [
                # IMDb
                render.Row(
                    main_align = "space_between",
                    expanded = True,
                    cross_align = "center",
                    children = [
                        render.Row(children = [popcorn_icon(parse_score(imdb)), render.Box(width = 3, height = 1), render.Text("IMDb", font = "tom-thumb", color = "#fc3")]),
                        render.Text(imdb, font = "tom-thumb", color = "#fff"),
                    ],
                ),
                # RT
                render.Row(
                    main_align = "space_between",
                    expanded = True,
                    cross_align = "center",
                    children = [
                        render.Row(children = [tomato_icon(parse_score(rt)), render.Box(width = 3, height = 1), render.Text("RT", font = "tom-thumb", color = "#f33")]),
                        render.Text(rt, font = "tom-thumb", color = "#fff"),
                    ],
                ),
                # Meta
                render.Row(
                    main_align = "space_between",
                    expanded = True,
                    cross_align = "center",
                    children = [
                        render.Row(children = [meta_icon(parse_score(meta)), render.Box(width = 3, height = 1), render.Text("Meta", font = "tom-thumb", color = "#3c3")]),
                        render.Text(meta, font = "tom-thumb", color = "#fff"),
                    ],
                ),
            ],
        ),
    )

# --- Icon Helpers ---

def tomato_icon(score):
    is_fresh = score >= 50
    if is_fresh:
        return render.Stack(children = [
            render.Box(width = 6, height = 6, color = "#0000"),
            render.Padding(pad = (1, 1, 0, 0), child = render.Box(width = 4, height = 4, color = "#f00")),
            render.Padding(pad = (2, 0, 0, 0), child = render.Box(width = 2, height = 1, color = "#0f0")),
        ])
    else:
        return render.Stack(children = [
            render.Box(width = 6, height = 6, color = "#0000"),
            render.Padding(pad = (1, 4, 0, 0), child = render.Box(width = 1, height = 1, color = "#0f0")),
            render.Padding(pad = (3, 4, 0, 0), child = render.Box(width = 2, height = 1, color = "#0f0")),
            render.Padding(pad = (0, 5, 0, 0), child = render.Box(width = 6, height = 1, color = "#0f0")),
        ])

def popcorn_icon(score):
    is_full = score >= 50
    kernel_color = "#ff0" if is_full else "#000"
    return render.Column(cross_align = "center", children = [
        render.Box(width = 3, height = 1, color = kernel_color),
        render.Box(width = 5, height = 1, color = kernel_color),
        render.Row(children = [
            render.Box(width = 1, height = 4, color = "#fff"),
            render.Box(width = 3, height = 4, color = "#f00"),
            render.Box(width = 1, height = 4, color = "#fff"),
        ]),
    ])

def meta_icon(score):
    is_good = score >= 50
    if is_good:
        return render.Stack(children = [
            render.Box(width = 6, height = 5, color = "#0000"),
            render.Padding(pad = (4, 0, 0, 0), child = render.Box(width = 1, height = 1, color = "#0f0")),
            render.Padding(pad = (3, 1, 0, 0), child = render.Box(width = 1, height = 1, color = "#0f0")),
            render.Padding(pad = (2, 2, 0, 0), child = render.Box(width = 1, height = 1, color = "#0f0")),
            render.Padding(pad = (1, 1, 0, 0), child = render.Box(width = 1, height = 1, color = "#0f0")),
        ])
    else:
        return render.Padding(pad = (0, 1, 0, 0), child = render.Text("X", font = "tom-thumb", color = "#f00"))

def get_schema():
    return schema.Schema(
        version = "1",
        fields = [
            schema.Text(
                id = "apikey",
                name = "OMDb API Key",
                desc = "Required: Your OMDb API Key",
                icon = "key",
            ),
            schema.Text(
                id = "movie",
                name = "Movie Name",
                desc = "The name of the movie to display",
                icon = "film",
            ),
            schema.Dropdown(
                id = "view_mode",
                name = "View Mode",
                desc = "Choose which view to display or cycle all",
                icon = "eye",
                default = "cycle",
                options = [
                    schema.Option(display = "Cycle All", value = "cycle"),
                    schema.Option(display = "Marquee Only", value = "marquee"),
                    schema.Option(display = "Poster Only", value = "poster"),
                    schema.Option(display = "Details Only", value = "details"),
                    schema.Option(display = "Ratings Only", value = "ratings"),
                ],
            ),
        ],
    )
