---
layout: page
permalink: /installation/
title: Installation
order: 2
---

#### DUB

If you are using dub add following dependency to your `dub.json` or `dub.sdl` file.

{% highlight js %}
{
    "dependencies": {
        "pack-d": "{{site.dub_version}}"
    }
}
{% endhighlight %}

{% highlight sdl %}
dependency "pack-d" version="{{site.dub_version}}"
{% endhighlight %}

#### Manual installation

1. Clone the repository

   ```shell
   $ git clone https://github.com/robik/pack-d
   ```

2. Add contents of `pack-d/source` directory to your project.
